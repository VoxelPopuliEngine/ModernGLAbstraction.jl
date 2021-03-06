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
    object
    msg::AbstractString
    StateError(object = missing, msg::AbstractString = "") = new(object, string(msg))
    StateError(msg::AbstractString) = new(missing, string(msg))
end


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

function Base.show(io::IO, err::OpenGLError)
    if err.code == ModernGL.GL_INVALID_ENUM
        write(io, "OpenGL Error: invalid enum")
    elseif err.code == ModernGL.GL_INVALID_VALUE
        write(io, "OpenGL Error: invalid value")
    elseif err.code == ModernGL.GL_INVALID_OPERATION
        write(io, "OpenGL Error: invalid operation")
    elseif err.code == ModernGL.GL_STACK_OVERFLOW
        write(io, "OpenGL Error: stack overflow")
    elseif err.code == ModernGL.GL_STACK_UNDERFLOW
        write(io, "OpenGL Error: stack underflow")
    elseif err.code == ModernGL.GL_OUT_OF_MEMORY
        write(io, "OpenGL Error: out of memory")
    elseif err.code == ModernGL.GL_INVALID_FRAMEBUFFER_OPERATION
        write(io, "OpenGL Error: invalid framebuffer operation")
    elseif err.code == 0x0507
        write(io, "OpenGL Error: context lost")
    else
        write(io, "OpenGL Error $(err.code)")
    end
end


macro should_never_reach()
    :(throw(ImplementationError("should never reach")))
end
