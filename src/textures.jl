######################################################################
# Low level OpenGL texture wrapper, abstractions & methods
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
@reexport module Textures
using ExtraFun
using ModernGL
using ..GraphicsLayer
import ..GraphicsLayer: @glassert, glsymbol

const Optional{T} = Union{T, Nothing}

export MipMapLevelError
struct MipMapLevelError <: Exception
  level::Integer
end

Base.show(io::IO, err::MipMapLevelError) = write(io, "MipMapLevelError: level $(err.level) ∉ [1, $(log(2, maxtexturesize()))]")


export Texture2DBase, Texture2D
"""`Texture2D{N}` resembles a texture image on the GPU, with `N` designating the number of color channels."""
struct Texture2DBase{N} <: Texture
  glid::Integer
end
const Texture2D = Texture2DBase{4}
GraphicsLayer.glsymbol(::Type{<:Texture2DBase}) = ModernGL.GL_TEXTURE_2D

export DSTextureBase, DSTexture
"""`DSTexture{N}` is a specialization of a `Texture2D{N}` for depth and/or stencil components. Accordingly,
 `N` is limited to 1 or 2. Additionally, Stencil-only textures can only be used on OpenGL 4.4+."""
struct DSTextureBase{N} <: Texture
  glid::Integer
end
const DSTexture = DSTextureBase{2}

GraphicsLayer.glenum(::Type{<:Texture2DBase}) = :GL_TEXTURE_2D
GraphicsLayer.glenum(::Type{<:DSTextureBase}) = :GL_TEXTURE_2D

export texture_channels
texture_channels(::Type{Texture2DBase{N}}) where N = N
texture_channels(::Type{DSTextureBase{N}}) where N = N
texture_channels(tex::Union{Texture2DBase, DSTextureBase}) = texture_channels(typeof(tex))


export texture
function texture(
    tex_t::Type{<:Texture2DBase},
    data::AbstractMatrix;
    level::Integer = 1,
    border::Integer = 0,
    generate_mipmaps::Bool = false,
    lifetime::Optional{Lifetime} = nothing
  )
  tex = texture(tex_t; lifetime=lifetime)
  upload_texture(tex, data, level=level, border=border)
  if generate_mipmaps
    generate_mipmaps(tex)
  end
  tex
end

function texture(tex_t::Type{<:Texture}, n::Integer = 1; lifetime::Optional{Lifetime} = nothing)
  if !(typeof(tex_t) <: DataType)
    throw(TypeError(:texture, "GraphicsLayer.Textures", DataType, typeof(tex_t)))
  end
  ids = zeros(UInt32, n)
  ModernGL.glGenTextures(n, pointer(ids))
  
  texes = tex_t[]
  for id ∈ ids
    tex = tex_t(id)
    push!(texes, tex)
    if lifetime !== nothing
      push!(lifetime, tex)
    end
  end
  
  if n == 1
    return texes[1]
  else
    return texes
  end
end

# RGBA Texture
export upload_texture
"""`upload_texture(tex::Texture2DBase, img::AbstractMatrix; level = 1, border = 0)`
 
 Upload a given RGBA texture `img` to the GPU & associate it with the given OpenGL texture resource `tex`.
 
 Components in `img` which are missing from `tex` are simply truncated. Components in `tex` missing from `img` are
 filled with 0 for green & blue channels, and 1 for alpha channel. It is thus possible to assign RGBA image data to a
 2-component RG texture and vice versa.
 
 `level` specifies the 1-based mipmap level of the texture. You may provide other levels yourself, or provide the base
 level and let OpenGL generate the others.
  
 `border` is an OpenGL-reserved argument which currently must be 0.
 
 See https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glTexImage2D.xhtml for more details.
 """
function upload_texture(tex::Texture2DBase{C}, img::AbstractMatrix{V}; level::Integer = 1, border::Integer = 0) where {C, V<:Vec}
  upload_texture_internal(
    tex,
    color_format(C),
    img,
    color_format(length(V)),
    eltype(V),
    level,
    border
  )
end
function upload_texture(tex::Texture2DBase{C}, img::AbstractMatrix{P}; level::Integer = 1, border::Integer = 0) where {C, P<:Packed}
  upload_texture_internal(
    tex,
    color_format(C),
    img,
    color_format(length(P)),
    P,
    level,
    border
  )
end

"""`upload_texture(tex::DSTextureBase, img::AbstractMatrix; level = 1, border = 0, stencil = false)`
 
 Specialization of `upload_texture` for `DSTextureBase`s - alternate `Texture2DBase`s designed for textures storing
 depth & stencil components.
 
 If the image data has only a single channel (`AbstractMatrix{<:Number}`), `stencil` keyword argument may be provided to
 determine whether this channel represents stencil or depth component respectively.
 """
function upload_texture(tex::DSTextureBase{1}, img::AbstractMatrix{<:Number}; level::Integer = 1, border::Integer = 0)
  upload_texture_internal(
    tex,
    ModernGL.GL_DEPTH_COMPONENT,
    img,
    ModernGL.GL_DEPTH_COMPONENT,
    eltype(img),
    level,
    border
  )
end
function upload_texture(tex::DSTextureBase{2}, img::AbstractMatrix{<:Number}; level::Integer = 1, border::Integer = 0, stencil::Bool = false)
  upload_texture_internal(
    tex,
    if stencil ModernGL.GL_DEPTH_STENCIL else ModernGL.GL_DEPTH_COMPONENT end,
    img,
    if stencil ModernGL.GL_STENCIL_INDEX else ModernGL.GL_DEPTH_COMPONENT end,
    eltype(img),
    level,
    border
  )
end
function upload_texture(tex::DSTextureBase{2}, img::AbstractMatrix{V}; level::Integer = 1, border::Integer = 0) where {V<:Vec2}
  upload_texture_internal(
    tex,
    ModernGL.GL_DEPTH_STENCIL,
    img,
    ModernGL.GL_DEPTH_STENCIL,
    eltype(V),
    level,
    border
  )
end

# Generic upload helper
function upload_texture_internal(
    tex::Texture2DBase,
    tex_format,
    img::AbstractMatrix,
    img_format,
    img_eltype::Type{<:Number},
    level::Integer,
    border::Integer,
  )
  use(tex)
  width, height = size(img)
  
  ModernGL.glTexImage2D(
    glsymbol(typeof(tex)),
    level-1,
    tex_format,
    width, height,
    border,
    img_format,
    glsymbol(img_eltype),
    pointer(img)
  )
  @glassert begin
    InvalidValue => begin
      if width > maxtexturesize() || height > maxtexturesize()
        ArgumentError("texture width ($width) or height ($height) > $(maxtexturesize())")
      elseif level-1 < 0 || level-1 > log(2, maxtexturesize())
        ArgumentError("mipmap level $(level-1) ∉ [0, $(log(2, maxtexturesize()))]")
      elseif border != 0
        ArgumentError("border argument must be 0")
      end
    end
  end
end

# Download RGBA Texture
export download_texture
"""`download_texture(tex::Texture2DBase; level = 1, border = 0)`
 
 Download image data associated with `tex` into `img`.
 
 `eltype(img)` is used to determine pixel type and may be any of OpenGL's supported primitives or `Packed` types.
 
 `format` describes the pixel format of the returned data. Currently, only specific formats are supported:
 
 - `:rgba` - RGBA color components of the texture
 - `:ds` - depth & stencil components of the texture
 
 `level` designates the 1-based mipmap level.
 """
function download_texture(tex::Texture2DBase; level::Integer = 1)
  width, height = size(tex)
  img = zeros(Vec4{UInt8}, width, height)
  download_texture(tex, img, level=level)
end
function download_texture(tex::Texture2DBase, img::AbstractMatrix{<:Number}; level::Integer = 1)
  download_texture_internal(
    tex,
    img,
    level,
    eltype(img),
    ModernGL.GL_RED
  )
end
function download_texture(tex::Texture2DBase, img::AbstractMatrix{V}; level::Integer = 1) where {N, V<:Vec{N}}
  download_texture_internal(
    tex,
    img,
    level,
    eltype(V),
    color_format(N)
  )
end
function download_texture(tex::Texture2DBase, img::AbstractMatrix{P}; level::Integer = 1) where {N, P<:Packed{N}}
  download_texture_internal(
    tex,
    img,
    level,
    P,
    color_format(N)
  )
end

function download_texture(tex::DSTextureBase, img::AbstractMatrix{<:Number}; level::Integer = 1, stencil::Bool = false)
  download_texture_internal(
    tex,
    img,
    level,
    eltype(img),
    if stencil ModernGL.GL_STENCIL_INDEX else ModernGL.GL_DEPTH_COMPONENT end
  )
end
function download_texture(tex::DSTextureBase, img::AbstractMatrix{V}; level::Integer = 1) where {V<:Vec2}
  download_texture_internal(
    tex,
    img,
    level,
    eltype(V),
    ModernGL.GL_DEPTH_STENCIL
  )
end
function download_texture(tex::DSTextureBase, img::AbstractMatrix{P}; level::Integer = 1) where {P<:Packed{2}}
  download_texture_internal(
    tex,
    img,
    level,
    P,
    ModernGL.GL_DEPTH_STENCIL
  )
end

function download_texture_internal(tex::Texture2DBase, img::AbstractMatrix, level::Integer, E::Type{<:Number}, format)
  ModernGL.glGetTextureImage(
    glid(tex),
    level,
    format, # of returned pixel data, not texture format
    glsymbol(E),
    length(img) * sizeof(eltype(img)),
    pointer(img)
  )
  @glassert begin
    InvalidOperation => begin
      if !ModernGL.glIsTexture(glid(tex))
        ArgumentError("not a valid texture - has it already been closed?")
      else
        InvalidOperationGLError()
      end
    end
    InvalidValue => begin
      if !is_valid_mipmap_level(level)
        MipMapLevelError(level)
      else
        InvalidValueGLError()
      end
    end
  end
end

export screenshot
"""`screenshot(tex::Texture2DBase, box::Box{UInt32}, format::Symbol = :rgba; level = 1, border = 0)`
 
 Capture a region of the rendered contents within the window and copy to `tex`.
 
 Captured region is designated by `box`, where `(box.x, box.y)` correspond to the top left corner of the window.
 
 `format` specifies the internal format of the texture and currently supports two values: `:rgba` for RGBA color
 components, and `:ds` for depth & stencil components.
 
 `level` designates the mipmap level of the texture.
 
 `border` is a reserved argument and currently must be 0.
 """
function screenshot(tex::Texture2DBase, box::Box{UInt32}, format::Symbol; level::Integer = 1, border::Integer = 0)
  use(tex)
  ModernGL.glCopyTexImage2D(glsymbol(tex), level, screenshot_format(Ident{format}()), box.x, box.y, box.w, box.h, border)
  @glassert begin
    InvalidValue => begin
      if !is_valid_mipmap_level(level)
        MipMapLevelError(level)
      elseif box.w ∉ 0:maxtexturesize() || box.h ∉ 0:maxtexturesize()
        ArgumentError("texture width $(box.w) or height $(box.h) ∉ 0:$(maxtexturesize())")
      elseif border != 0
        ArgumentError("texture border must be 0")
      end
    end
    InvalidOperation => ArgumentError("requested depth/stencil image without depth/stencil buffer")
  end
end

screenshot_format(::Ident{:rgba}) = ModernGL.GL_RGBA
screenshot_format(::Ident{:ds}) = ModernGL.GL_DEPTH_STENCIL

function Base.size(tex::Texture2DBase; level::Integer = 1)
  width  = Ref{Int32}()
  height = Ref{Int32}()
  
  ModernGL.glGetTextureLevelParameteriv(glid(tex), level-1, ModernGL.GL_TEXTURE_WIDTH, width)
  @glassert begin
    InvalidOperation => ArgumentError("GLID is not a texture - has it already been destroyed?")
    InvalidValue => MipMapLevelError(level)
  end
  
  ModernGL.glGetTextureLevelParameteriv(glid(tex), level-1, ModernGL.GL_TEXTURE_HEIGHT, height)
  @glassert begin
    InvalidOperation => ArgumentError("GLID is not a texture - has it already been destroyed?")
    InvalidValue => MipMapLevelError(level)
  end
  
  width[], ref[]
end

export generate_mipmaps
function generate_mipmaps(tex::Texture)
  use(tex)
  ModernGL.glGenerateMipmap(glsymbol(typeof(tex)))
  @glassert begin end # should not happen - unless tex has already been closed
end

function get_internal_format(tex::Texture, level::Integer = 1)
  ref = Ref{Int32}(0)
  ModernGL.glGetTextureLevelParameteriv(glid(tex), level-1, ModernGL.GL_TEXTURE_INTERNAL_FORMAT, ref)
  @glassert begin
    InvalidOperation => ArgumentError("glid(tex) = $(glid(tex)) is not a texture - has it been destroyed already?")
    InvalidValue => MipMapLevelError(level)
  end
  ref[]
end

function ExtraFun.use(tex::Texture; unit::Integer = 1)
  ModernGL.glActiveTexture(ModernGL.GL_TEXTURE0 + unit-1)
  @glassert begin
    InvalidEnum => ArgumentError("texture unit $unit ∉ [1, $(maxtexturecount())]")
  end
  
  ModernGL.glBindTexture(glsymbol(typeof(tex)), tex.glid)
  @glassert begin end # should never happen, really
  
  tex
end


export texture_wrapping
"""`texture_wrapping(tex, uwrap, vwrap)`
 
 Set texture wrapping for `Texture2DBase` and `DSTextureBase`.
 
 Both `uwrap` and `vwrap` may be any of the following symbols:
 
 - `:repeat`
 - `:mirror` - repeat mirrored
 - `:clampToEdge`
 - `:clampToBorder`
 - `:clampToMirror` - clamp to edge mirrored
 """
function texture_wrapping(tex::Union{Texture2DBase, DSTextureBase}, uwrap::Symbol, vwrap::Symbol)
  gltex = glsymbol(typeof(tex))
  
  ModernGL.glTexParameteri(gltex, ModernGL.GL_TEXTURE_WRAP_S, wrapsymbol(uwrap))
  @glassert begin end
  
  ModernGL.glTexParameteri(gltex, ModernGL.GL_TEXTURE_WRAP_T, wrapsymbol(vwrap))
  @glassert begin end
  
  tex
end

wrapsymbol(symbol::Symbol) = wrapsymbol(Ident{symbol}())
wrapsymbol(::Ident{:repeat}) = ModernGL.GL_REPEAT
wrapsymbol(::Ident{:mirror}) = ModernGL.GL_MIRRORED_REPEAT
wrapsymbol(::Ident{:clampToEdge}) = ModernGL.GL_CLAMP_TO_EDGE
wrapsymbol(::Ident{:clampToBorder}) = ModernGL.GL_CLAMP_TO_BORDER
wrapsymbol(::Ident{:clampToMirror}) = ModernGL.GL_MIRROR_CLAMP_TO_EDGE

export texture_border
texture_border(tex::Texture2DBase, gray::Float32) = texture_border_internal(tex, [fill(gray, 3)..., 1])
texture_border(tex::Texture2DBase, red::Float32, green::Float32, blue::Float32, alpha::Float32 = 1f) = texture_border_internal(tex, [red, green, blue, alpha])
function texture_border_internal(tex::Texture2DBase, border::AbstractVector{Float32})
  # assume border has proper length
  ModernGL.glTexParameterfv(glenum(tex), ModernGL.GL_TEXTURE_BORDER_COLOR, pointer(border))
  @glassert begin end
end


color_format(channels::Integer) = if channels == 1 ModernGL.GL_RED else glsymbol(Symbol("GL_" * "RGBA"[1:channels])) end

is_valid_mipmap_level(level::Integer) = level ∈ 1:log(2, maxtexturesize())

function maxtexturesize()
  global _maxtexturesize
  if _maxtexturesize === nothing
    ref = Ref{Int32}(0)
    ModernGL.glGetIntegerv(ModernGL.GL_MAX_TEXTURE_SIZE, ref)
    @glassert begin end
    _maxtexturesize = ref[]
  end
  _maxtexturesize
end
_maxtexturesize = nothing

function maxtexturecount()
  global _maxtexturecount
  if _maxtexturecount === nothing
    ref = Ref{Int32}(0)
    ModernGL.glGetIntegerv(ModernGL.GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, ref)
    @glassert begin end
    _maxtexturecount = ref[]
  end
  _maxtexturecount
end
_maxtexturecount = nothing

end # module Textures
