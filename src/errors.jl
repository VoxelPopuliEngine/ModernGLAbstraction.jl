######################################################################
# Errors used throughout the library
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1

struct ImplementationError <: Exception
    msg::AbstractString
end

function Base.show(io::IO, err::ImplementationError)
    write(io, "library-internal implementation error: $(err.msg)")
end


struct StateError <: Exception
    msg::AbstractString
end
StateError() = StateError("")


export OpenGLError, InvalidEnumGLError, InvalidValueGLError, InvalidOperationGLError, StackOverflowGLError, StackUnderflowGLError, OutOfMemoryGLError, InvalidFramebufferOperationGLError, ContextLostGLError, TableTooLargeGLError
struct OpenGLError <: Exception
    code::UInt32
end
InvalidEnumGLError() = OpenGLError(ModernGL.GL_INVALID_ENUM)
InvalidValueGLError() = OpenGLError(ModernGL.GL_INVALID_VALUE)
InvalidOperationGLError() = OpenGLError(ModernGL.GL_INVALID_OPERATION)
StackOverflowGLError() = OpenGLError(ModernGL.GL_STACK_OVERFLOW)
StackUnderflowGLError() = OpenGLError(ModernGL.GL_STACK_UNDERFLOW)
OutOfMemoryGLError() = OpenGLError(ModernGL.GL_OUT_OF_MEMORY)
InvalidFramebufferOperationGLError() = OpenGLError(ModernGL.GL_INVALID_FRAMEBUFFER_OPERATION)
ContextLostGLError() = OpenGLError(0x0507) # OGL 4.5 or ARB_KHR_robustness


macro should_never_reach()
    :(throw(ImplementationError("should never reach")))
end
