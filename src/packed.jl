######################################################################
# Packed types for texture data
using GenerateProperties

export Packed
"""Abstract type for packed pixel data.
 
 @see `Packed_8_8_8_8`, `Packed_10_10_10_2`
 """
abstract type Packed{N} <: Unsigned end
Base.length(::Union{<:Packed{N}, Type{<:Packed{N}}}) where N = N
Base.size(::Union{<:Packed{N}, Type{<:Packed{N}}}) where N = (N,)

export Packed_8_8_8_8
"""Packed type allocating 8 bits for 4 channels.
 
 As it is intended for RGBA, it provides `r`, `g`, `b`, and `a` virtual properties, each as `UInt8`.
 """
struct Packed_8_8_8_8 <: Packed{4}
  value::UInt32
end
glname(::Type{Packed_8_8_8_8}) = :GL_UNSIGNED_INT_8_8_8_8

@generate_properties Packed_8_8_8_8 begin
  @get r = (self.value & 0xFF000000) >> UInt8(24)
  @get g = (self.value & 0x00FF0000) >> UInt8(16)
  @get b = (self.value & 0x0000FF00) >> UInt8( 8)
  @get a = (self.value & 0x000000FF) >> UInt8( 0)
end

export Packed_10_10_10_2
"""Packed type allocating 10 bits to the first 3 channels and another 2 bits for the last.
 
 As it is intended for RGBA, it provides `r`, `g`, `b`, and `a` virtual properties, each as `UInt32`.
 """
struct Packed_10_10_10_2 <: Packed{4}
  value::UInt32
end
glname(::Type{Packed_10_10_10_2}) = :GL_UNSIGNED_INT_10_10_10_2

@generate_properties Packed_10_10_10_2 begin
  @get r = (self.value & 0xFFC00000) >> 22
  @get g = (self.value & 0x003FF000) >> 12
  @get b = (self.value & 0x00000FFC) >>  2
  @get a = (self.value & 0x00000003) >>  0
end
