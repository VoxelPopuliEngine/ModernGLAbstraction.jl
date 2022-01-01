######################################################################
# Low level OpenGL uniform abstraction.
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
@reexport module Uniforms
using Base: isiterable
using ModernGL
using StaticArrays
using ExtraFun: iterable, Optional, Unknown, unknown
using ModernGLAbstraction
using ..ModernGLAbstraction: glsymbol, StateError, ImplementationError, @glassert
import ExtraFun


export Uniform
struct Uniform{T}
    prog::Program
    name::Symbol
    location::Int32
    index::Optional{:uniform_index, UInt32}
end
Uniform{T}(prog::Program, name::Symbol) where T = Uniform{T}(prog, name, ModernGLAbstraction.Shaders.finduniform(prog, name), unknown)
Uniform(T::Type, prog::Program, name::Symbol) = Uniform{T}(prog, name)

function ExtraFun.load(uniform::Uniform)
    name = string(uniform.name)
    ref  = Ref{UInt32}()
    ModernGL.glGetUniformIndices(uniform.prog, 1, pointer([pointer(name)]), ref)
    uniform.index = ref[]
end
ExtraFun.isunknown(uniform::Uniform) = isunknown(uniform.index)


export uniform
uniform(as::Type{<:Real}, location::Integer, args::Real...) = uniform_internal(as, location, args)
uniform(as::Type{<:Real}, location::Integer, values) = uniform_internal(as, location, values)
uniform(as::Type{<:Vec{1}}, location::Integer, vec) = uniform_internal(as, location, (vec,))
uniform(as::Type{<:Vec{N}}, location::Integer, vecs) where N = uniform_internal(as, location, vecs)
uniform(as::Type{<:Mat{M, N, Float32}}, location::Integer, mat::AbstractMatrix{Real}) where {M, N} = uniform_mat(as, location, mat)
uniform(as::Type{<:Mat{M, N, Float32}}, location::Integer, mats) where {M, N} = uniform_mat(as, location, mats)

# Bind sampler uniform at `location` to texture `unit`.
# uniform(::Type{<:GLSampler}, location::Integer, unit::Integer) = (@assertarg(unit ∈ 1:maxtexturecount()); uniform(GLInteger{Int32}, location, Int32(unit-1)))
# # Bind the actual texture to `unit`.
# uniform(::Type{<:GLSampler}, unit::Integer, tex::Texture) = use(tex, unit=unit)

# Upload array of vectors or scalars
function uniform_internal(as::Type{<:Real}, location::Integer, values)
    length(values) ∈ 1:4 || throw(ArgumentError("too many arguments, expected 1 to 4"))
    active_program()
    
    fn = uniform_fn(uniform_fn_base(as, length(values)))
    fn(location, as.(values)...)
    @glassert
    nothing
end
function uniform_internal(as::Type{<:Vec{1, T}}, location::Integer, values) where T
    active_program()
    values = append!(T[], values)
    
    fn = uniform_fn(uniform_fn_base(as))
    fn(location, length(values), pointer(values))
    @glassert
    nothing
end
function uniform_internal(as::Type{<:Vec{N, T}}, location::Integer, vecs) where {N, T}
    isiterable(eltype(vecs)) || throw(ArgumentError("expected collection of iterables, got collection of $(eltype(vecs))"))
    active_program()
    values = append!(T[], require_elements.(N, vecs)...)
    
    fn = uniform_fn(uniform_fn_base(as))
    fn(location, length(vecs), pointer(values))
    @glassert
    nothing
end
function uniform_internal(as::Type{<:Mat{M, N, T}}, location::Integer, mats) where {M, N, T}
    eltype(mats) <: Mat{M, N} || throw(ArgumentError("invalid iterator element type $(eltype(mats)), expected Mat{$M, $N}"))
    active_program()
    values = append!(T[], mats...)
    
    fn = uniform_fn(uniform_fn_base(as))
    fn(location, length(mats), pointer(values))
    @glassert
    nothing
end

# TODO: Upload array of matrices

uniform_fn(fn::Symbol) = getproperty(ModernGL, fn)
uniform_fn_base(T::Type, count::Integer) = Symbol("glUniform$(count)$(uniform_fn_type(T))")
uniform_fn_base(::Type{Vec{N, T}}) where {N, T} = Symbol("glUniform$(N)$(uniform_fn_type(T))v")
uniform_fn_base(::Type{Mat{N, N, Float32}}) where {N}    = Symbol("glUniformMatrix$(N)fv")
uniform_fn_base(::Type{Mat{N, M, Float32}}) where {N, M} = Symbol("glUniformMatrix$(N)x$(M)fv")
uniform_fn_type(::Type{Int32}) = 'i'
uniform_fn_type(::Type{UInt32}) = "ui"
uniform_fn_type(::Type{Float32}) = 'f'


uniform_index(prog::Program, name) = uniform_index(prog, string(name))
function uniform_index(prog::Program, name::String)
    isvalid(prog) || throw(StateError("invalid/destroyed program"))
    idx = Ref{ModernGL.GLuint}()
    ModernGL.glGetUniformIndices(prog.glid, 1, pointer([pointer(name)]), idx)
    @glassert begin
        InvalidOperation => ImplementationError("invalid/unlinked program")
    end
    idx[]
end

"""`parameter(prog::Program, locations, param::UInt32)`
Retrieve the uniform parameter `param` of all uniforms identified by `locations` within `prog`. `locations` may be any
iterable collection of `Integer` (convertible to `UInt32`), or a singular location.

If only one location is requested the return value will be the corresponding value. Otherwise, returns a collection of
all values."""
parameter(prog::Program, name, param::UInt32) = parameter(prog, string(name), param)
function parameter(prog::Program, name::String, param::UInt32)
    isvalid(prog) || throw(StateError("invalid/destroyed program"))
    
    index = Ref{ModernGL.GLuint}(uniform_index(prog, name))
    result = Ref{ModernGL.GLint}()
    ModernGL.glGetActiveUniformsiv(prog.glid, 1, index, param, result)
    @glassert begin
        InvalidEnum => ArgumentError("invalid parameter")
        InvalidOperation => ImplementationError("not a program object")
    end
    return result[]
end


# Test whether uniform is valid.
# WARNING: This is a comparatively resource intense algorithm and should be avoided in a production build.
function Base.isvalid(uni::Uniform{T}) where T
    uni.location == ModernGLAbstraction.Shaders.finduniform(uni.prog, uni.name) || error("uniform location mismatch")
    uni.location > -1 || error("negative uniform location")
    glsymbol(T) == parameter(uni.prog, uni.name, ModernGL.GL_UNIFORM_TYPE)
end

Base.size(uni::Uniform) = parameter(uni.prog, uni.name, ModernGL.GL_UNIFORM_SIZE)


function require_elements(N, it)
    N > 0 || throw(ArgumentError("N($N) must be positive"))
    _, state = iterate(it)
    for _ ∈ 2:N
        res = iterate(it, state)
        res !== nothing || throw(ArgumentError("too few elements"))
        _, state = res
    end
    iterate(it, state) === nothing || throw(ArgumentError("too many elements"))
    return it
end

end # module Uniforms
