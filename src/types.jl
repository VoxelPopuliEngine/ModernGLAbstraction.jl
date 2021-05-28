######################################################################
# GraphicsLayer abstract type definitions
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using StaticArrays

export Vec, Vec2, Vec3, Vec4
const Vec{N, T} = SVector{N, T}
const Vec2{T} = Vec{2, T}
const Vec3{T} = Vec{3, T}
const Vec4{T} = Vec{4, T}

export Mat, Mat2, Mat3, Mat4
const Mat{N, M, T} = SMatrix{N, M, T}
const MatN{N, T} = Mat{N, N, T}
const Mat2{T} = MatN{2, T}
const Mat3{T} = MatN{3, T}
const Mat4{T} = MatN{4, T}

export Buffer, Shader
abstract type Buffer end
abstract type Shader end

export Texture
abstract type Texture end


glname(::Type{Bool})    = :GL_BOOL
glname(::Type{Int8})    = :GL_BYTE
glname(::Type{UInt8})   = :GL_UNSIGNED_BYTE
glname(::Type{Int16})   = :GL_SHORT
glname(::Type{UInt16})  = :GL_UNSIGNED_SHORT
glname(::Type{Int32})   = :GL_INT
glname(::Type{UInt32})  = :GL_UNSIGNED_INT
glname(::Type{Float32}) = :GL_FLOAT
glname(::Type{Float64}) = :GL_DOUBLE
glname(::Type{Vec{N, T}}) where {N, T<:Union{Bool, UInt32, Int32, Float32, Float64}} = N ∈ 2:4 ? Symbol(string(glname(T) * "_VEC$N")) : throw(ArgumentError("invalid vector size $N, expected ∈ 2:4"))
glname(::Type{Mat{N, N, T}}) where {N, T<:Union{Float32, Float64}} = N ∈ 2:4 ? Symbol(string(glname(T) * "_MAT$N")) : throw(ArgumentError("invalid square matrix size $N, expected ∈ 2:4"))
glname(::Type{Mat{N, M, T}}) where {N, M, T<:Union{Float32, Float64}} = N ∈ 2:4 && M ∈ 2:4 ? Symbol(string(glname(T) * "_MAT$Nx$M")) : throw(ArgumentError("invalid matrix size $N×$M, expected N,M ∈ 2:4"))
# TODO: Textures/Samplers, Images

# Generic helper
glsymbol(name::Symbol) = getproperty(ModernGL, name)
glsymbol(T::Type) = glsymbol(glname(T))
