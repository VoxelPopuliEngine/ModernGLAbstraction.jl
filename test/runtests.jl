######################################################################
# Epicentral test inclusion
# -----
# Licensed under LPGL-2.1

nothrow(cb) = (cb(); true)

include("./test_lifetimes.jl")
include("./test_buffers.jl")
include("./test_shaders.jl")
include("./test_textures.jl")
