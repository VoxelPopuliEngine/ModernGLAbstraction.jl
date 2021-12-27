######################################################################
# Function stubs used throughout the library.
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1

export glenum, glid

glenum() = throw(MethodError(glenum, ()))
glid(x) = x.glid
glname() = throw(MethodError(glname, ()))
glsymbol(name::Symbol) = getproperty(ModernGL, name)
glsymbol(T::Type) = glsymbol(glname(T))
