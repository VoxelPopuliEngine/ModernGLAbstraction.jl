######################################################################
# Low level abstraction of OpenGL buffers.
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
@reexport module Buffers
import ModernGL
using ExtraFun
using RuntimeEnums
using StaticArrays
using ..GraphicsLayer
import ..GraphicsLayer: bytes, glenum, glid, @glassert, @should_never_reach

const Optional{T} = Union{T, Nothing}

struct BufferVolatility{S} end
struct BufferUsage{S} end
"""`glbufferusage(volatility::Symbol, usage::Symbol)`
 
 Get the OpenGL enumerator representing the the buffer usage of `volatility` with `usage`.
 
 `volatility` may assume any of these symbols:
 
 - :static  - The buffer data will not be touched again once uploaded.
 - :dynamic - The buffer data will occasionally be updated.
 - :stream  - The buffer data will frequently be updated, possibly every frame.
 
 `usage` may assume any of these symbols:
 
 - :draw - The buffer data is intended only for rendering on screen.
 - :read - The buffer data is modified by OpenGL (and its shaders) and can be copied back to the client.
 - :copy - Essentially :draw and :read combined."""
glbufferusage(volatility::Symbol, usage::Symbol) = glbufferusage(BufferVolatility{volatility}(), BufferUsage{usage}())
glbufferusage(::BufferVolatility{:stream},  ::BufferUsage{:draw}) = ModernGL.GL_STREAM_DRAW
glbufferusage(::BufferVolatility{:stream},  ::BufferUsage{:read}) = ModernGL.GL_STREAM_READ
glbufferusage(::BufferVolatility{:stream},  ::BufferUsage{:copy}) = ModernGL.GL_STREAM_COPY
glbufferusage(::BufferVolatility{:static},  ::BufferUsage{:draw}) = ModernGL.GL_STATIC_DRAW
glbufferusage(::BufferVolatility{:static},  ::BufferUsage{:read}) = ModernGL.GL_STATIC_READ
glbufferusage(::BufferVolatility{:static},  ::BufferUsage{:copy}) = ModernGL.GL_STATIC_COPY
glbufferusage(::BufferVolatility{:dynamic}, ::BufferUsage{:draw}) = ModernGL.GL_DYNAMIC_DRAW
glbufferusage(::BufferVolatility{:dynamic}, ::BufferUsage{:read}) = ModernGL.GL_DYNAMIC_READ
glbufferusage(::BufferVolatility{:dynamic}, ::BufferUsage{:copy}) = ModernGL.GL_DYNAMIC_COPY

export GLBufferType, ArrayBufferType, ElementArrayBufferType, TextureBufferType, UniformBufferType
@runtime_enum GLBufferType ArrayBufferType ElementArrayBufferType TextureBufferType UniformBufferType

export ArrayBuffer, ElementArrayBuffer, TextureBuffer, UniformBuffer
mutable struct GLBuffer{S} <: Buffer
    glid::UInt32
    function GLBuffer{S}(glid) where S
        if !isa(S, GLBufferType)
            throw(ArgumentError("Invalid parameter: not a GLBufferType"))
        end
        new(glid)
    end
end
const ArrayBuffer        = GLBuffer{ArrayBufferType}
const ElementArrayBuffer = GLBuffer{ElementArrayBufferType}
const TextureBuffer      = GLBuffer{TextureBufferType}
const UniformBuffer      = GLBuffer{UniformBufferType}
GraphicsLayer.glenum(::Type{GLBuffer{ArrayBufferType}}) = ModernGL.GL_ARRAY_BUFFER
GraphicsLayer.glenum(::Type{GLBuffer{ElementArrayBufferType}}) = ModernGL.GL_ELEMENT_ARRAY_BUFFER
GraphicsLayer.glenum(::Type{GLBuffer{TextureBufferType}}) = ModernGL.GL_TEXTURE_BUFFER
GraphicsLayer.glenum(::Type{GLBuffer{UniformBufferType}}) = ModernGL.GL_UNIFORM_BUFFER
GraphicsLayer.glid(buff::GLBuffer) = buff.glid

buffertype(::Union{Type{GLBuffer{S}}, GLBuffer{S}}) where S = S


export buffer
"""`buffer(::Type{<:GLBuffer}, data, volatility::Symbol, usage::Symbol; lifetime = nothing, mapper = identity)`
Instantiate a single new GPU buffer of `type` with given `volatility` & `usage` and initialize it with `data`.

If `lifetime` is a valid `Lifetime` object, the buffer will be hooked into the corresponding resource lifetime management system.

If `mapper` is specified, it will be applied to every item in `data` and its results stored within the GPU buffer instead.

Combined, `volatility` & `usage` describe storage optimization of the buffer on the GPU.

`volatility` can be one of these symbols:

- `:stream`: indicates buffer will be frequently updated
- `:static`: indicates buffer will be uploaded once and never touched again
- `:dynamic`: indicates buffer will be occasionally updated

`usage` can be one of these symbols:

- `:draw`: indicates the buffer will be used to render primitives on screen only
- `:read`: indicates the buffer will be used to render & download back to CPU/RAM
- `:copy`: indicates the buffer will be used to render & as target for memory operations on the GPU
"""
function buffer(T::Type{<:GLBuffer}, data, volatility::Symbol, usage::Symbol; lifetime::Optional{Lifetime} = nothing, mapper = identity)
    buff = buffer(T)
    if lifetime !== nothing
        push!(lifetime, buff)
    end
    
    use(buff)
    buffer_init(buff, data, volatility, usage, mapper=mapper)
    return buff
end

"""`buffer(type::BufferType, n = 1)`
Allocates `n` OpenGL buffers of `T` on the GPU."""
function buffer(T::Type{<:GLBuffer}, n::Integer = 1)
    @assert n > 0
    ids = zeros(UInt32, n)
    ModernGL.glGenBuffers(n, pointer(ids))
    @glassert begin
        InvalidValue => DomainError(:n, "must be non-negative")
    end
    
    buffers = T.(ids)
    
    if n == 1
        return first(buffers)
    else
        return buffers
    end
end

buffer_init(buff::Buffer, data, volatility::Symbol, usage::Symbol; mapper = identity) = buffer_init(buff, bytes(data, mapper=mapper), volatility, usage)
function buffer_init(buff::Buffer, data::Vector{UInt8}, volatility::Symbol, usage::Symbol)
    use(buff)
    ModernGL.glBufferData(glenum(typeof(buff)), sizeof(data), pointer(data), glbufferusage(volatility, usage))
    @glassert begin
        InvalidEnum  => ImplementationError("invalid buffer target or usage")
        InvalidValue => ImplementationError("size is negative")
        InvalidOperation => ImplementationError("bound buffer is 0")
    end
    nothing
end

export buffer_update
"""`buffer_update(buff::Buffer, data; offset = 0, mapper = identity)`
Update/override the contents of the GPU buffer `buff` with `data`, starting at 0-based `offset`. `mapper` will be applied
to every element of the `data`. Cannot supply more data than the buffer was originally supplied with, which can be
retrieved with `Base.size(buff)`."""
buffer_update(buff::Buffer, data; offset::Integer = 0, mapper = identity) = buffer_update(buff, bytes(data, mapper=mapper); offset=offset)
function buffer_update(buff::Buffer, data::Vector{UInt8}; offset::Integer = 0)
    use(buff)
    ModernGL.glBufferSubData(glenum(typeof(buff)), offset, sizeof(data), pointer(data))
    @glassert begin
        InvalidEnum  => ImplementationError("invalid buffer target or usage")
        InvalidValue => begin
            if sizeof(data) < 0
                ImplementationError("size is negative")
            elseif offset < 0
                DomainError(:offset, "offset must be non-negative")
            elseif buffertype(buff) ∈ (ArrayBufferType, ElementArrayBufferType) && sizeof(data) + offset > size(buff)
                BoundsError("size + offset exceed buffer bounds")
            else
                ImplementationError("unknown GL_INVALID_VALUE error cause")
            end
        end
        InvalidOperation => ImplementationError("bound buffer is 0")
    end
    nothing
end

export buffer_download!
"""`buffer_download!(data::AbstractVector{UInt8}, buff::Buffer, size; offset = 0)`
Download `size` bytes from the GPU buffer `buff` into `data` starting at 0-based `offset`. The data will always be in bytes."""
function buffer_download!(data::AbstractVector{UInt8}, buff::Buffer, size::Integer; offset::Integer = 0)
    use(buff)
    if length(data) < size
        resize!(data, size)
    end
    ModernGL.glGetBufferSubData(glenum(typeof(buff)), UInt32(offset), UInt32(size), pointer(data))
    @glassert begin
        InvalidEnum  => ImplementationError("invalid target")
        InvalidValue => begin
            if size < 0
                DomainError(:size, "must be non-negative")
            elseif offset < 0
                DomainError(:offset, "must be non-negative")
            elseif size + offset > Base.size(buff)
                BoundsError("size + offset exceed bounds of buffer")
            end
        end
        InvalidOperation => ImplementationError("bound buffer is 0, or buffer is mapped")
    end
    nothing
end

export buffer_download
"""`buffer_download(buff::Buffer, size; offset = 0)`
Download `size` bytes from the GPU buffer `buff` starting at 0-based `offset` and return them. The data will always be in bytes."""
function buffer_download(buff::Buffer, size::Integer; offset::Integer = 0)
    ret = UInt8[]
    buffer_download!(ret, buff, size, offset=offset)
    return ret
end

function ExtraFun.use(buff::Buffer)
    ModernGL.glBindBuffer(glenum(typeof(buff)), glid(buff))
    @glassert begin
        InvalidEnum  => ImplementationError("invalid target")
        InvalidValue => ImplementationError("invalid buffer name")
    end
    buff
end

function Base.close(buff::Buffer)
    if isvalid(buff)
        id = Ref{UInt32}(glid(buff))
        ModernGL.glDeleteBuffers(1, id)
        @glassert begin
            InvalidValue => @should_never_reach
        end
        buff.glid = 0
    end
    buff
end

Base.isvalid(buff::Buffer) = glid(buff) > 0
Base.size(buff::Buffer) = parameter(buff, ModernGL.GL_BUFFER_SIZE)

export buffer_usage, buffer_mapped
buffer_usage(buff::Buffer) = parameter(buff, ModernGL.GL_BUFFER_USAGE)
buffer_mapped(buff::Buffer) = parameter(buff, ModernGL.GL_BUFFER_MAPPED) != 0


function parameter(buff::Buffer, param::UInt32)
    ref = Ref{ModernGL.GLint}()
    use(buff)
    ModernGL.glGetBufferParameteriv(glenum(typeof(buff)), param, ref)
    @glassert begin
        InvalidEnum => ImplementationError("invalid target or parameter name")
        InvalidOperation => ImplementationError("bound buffer is 0")
    end
    ref[]
end
function parameter64(buff::Buffer, param::UInt32)
    ref = Ref{ModernGL.GLint64}()
    use(buff)
    ModernGL.glGetBufferParameteri64v(glenum(typeof(buff)), param, ref)
    @glassert begin
        InvalidEnum => ImplementationError("invalid target or parameter name")
        InvalidOperation => ImplementationError("bound buffer is 0")
    end
    ref[]
end

end # module Buffers
