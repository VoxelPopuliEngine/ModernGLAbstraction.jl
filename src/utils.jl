######################################################################
# Utility functions used throughout the library
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using ExtraFun

function bytes(x; mapper = identity)
    x = iterable(x)
    buffer = IOBuffer()
    for item ∈ x
        write(buffer, mapper(item))
    end
    take!(buffer)
end
