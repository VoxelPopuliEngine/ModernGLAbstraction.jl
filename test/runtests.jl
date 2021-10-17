######################################################################
# Epicentral test inclusion
# -----
# Licensed under LPGL-2.1

nothrow(cb) = (cb(); true)

include("./Test.Lifetimes.jl")
include("./Test.Buffers.jl")
include("./Test.Shaders.jl")
