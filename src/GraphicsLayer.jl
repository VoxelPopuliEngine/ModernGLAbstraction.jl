######################################################################
# Epicentral import & inclusion module
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
module ModernGLAbstraction
using Reexport

include("./errors.jl")
include("./glassert.jl")
include("./stubs.jl")
include("./types.jl")
include("./lifetimes.jl")
include("./utils.jl") 

include("./fragfilters.jl")
include("./buffers.jl")
include("./shaders.jl")
include("./uniforms.jl")
# include("./layouts.jl")
include("./textures.jl")

# include("./Draws.jl")

end # module
