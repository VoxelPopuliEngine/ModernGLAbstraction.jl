######################################################################
# Utility functions used throughout the library
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using KirUtil
using ModernGL

function bytes(x; mapper = identity)
    x = iterable(x)
    buffer = IOBuffer()
    for item ∈ x
        write(buffer, mapper(item))
    end
    take!(buffer)
end

function glstate(T::Type, enum::ModernGL.GLenum)
    ref = Ref{T}()
    glstate_fun(T)(enum, ref)
    @glassert begin
        InvalidEnum => ArgumentError("invalid OpenGL enum")
    end
    ref[]
end
glstate_fun(::Type{Bool}) = ModernGL.glGetBooleanv
glstate_fun(::Type{Int32}) = ModernGL.glGetIntegerv
glstate_fun(::Type{Int64}) = ModernGL.glGetInteger64v
glstate_fun(::Type{Float64}) = ModernGL.glGetDoublev
glstate_fun(::Type{Float32}) = ModernGL.glGetFloatv

function glstatei(T::Type, enum::ModernGL.GLenum, idx::Integer)
    ref = Ref{T}()
    glstatei_fun(T)(enum, idx, ref)
    @glassert begin
        InvalidEnum => ArgumentError("invalid OpenGL enum")
        InvalidValue => BoundsError(nothing, idx)
    end
    val
end
glstatei_fun(::Type{Bool}) = ModernGL.glGetBooleani_v
glstatei_fun(::Type{Int32}) = ModernGL.glGetIntegeri_v
glstatei_fun(::Type{Int64}) = ModernGL.glGetInteger64i_v
glstatei_fun(::Type{Float64}) = ModernGL.glGetDoublei_v
glstatei_fun(::Type{Float32}) = ModernGL.glGetFloati_v
