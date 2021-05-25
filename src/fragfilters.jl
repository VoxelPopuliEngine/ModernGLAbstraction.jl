######################################################################
# Low Level abstraction of OpenGL stencil methods.
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
@reexport module FragFilters
using ExtraFun: Ident
using ModernGL
using ..GraphicsLayer

export depthfunc, stencilfunc
export stencilop

export FragFace, FrontFace, BackFace, BothFaces
@enum FragFace FrontFace BackFace BothFaces


export fragmask
"""`fragmask(color, depth, stencil)`
Sets color, depth, and stencil masks. `color` sets the mask for all color channels. Can be used to enable or disable writing to a certain buffer (or channel).

See also [`colormask`](@ref), [`depthmask`](@ref), [`stencilmask`](@ref)."""
function fragmask(color, depth, stencil)
    colormask(color)
    depthmask(depth)
    stencilmask(stencil)
end
"""`fragmask(red, green, blue, alpha, depth, stencil)`
Sets the color, depth, and stencil masks. Can be used to enable or disable writing to a certain buffer (or channel).

See also [`colormask`](@ref), [`depthmask`](@ref), [`stencilmask`](@ref)."""
function fragmask(red, green, blue, alpha, depth, stencil)
    colormask(red, green, blue, alpha)
    depthmask(depth)
    stencilmask(stencil)
end

export colormask
"""`colormask(mask::Bool) = colormask(mask, mask, mask, mask)`"""
colormask(mask::Bool) = colormask(mask, mask, mask, mask)
"""`colormask(red, green, blue, alpha)`
Restrict whether or not fragment shaders may write to the color buffer per channel/component. All arguments are `Bool`."""
colormask(red::Bool, green::Bool, blue::Bool, alpha::Bool) = ModernGL.glColorMask(red, green, blue, alpha)
"""`colormask(buffidx::Integer, red::Bool, green::Bool, blue::Bool, alpha::Bool)`
Restrict whether or not fragment shaders may write to the `buffidx`'th color buffer per channel/component of the active
[Framebuffer Object](https://www.khronos.org/opengl/wiki/Framebuffer_Object)."""
colormask(buffidx::Integer, red::Bool, green::Bool, blue::Bool, alpha::Bool) = ModernGL.glColorMaski(buffidx, red, green, blue, alpha)

export depthmask
"""`depthmask(mask::Integer)`
Set the integer bit mask with which to AND the depth buffer and fragment depth values before comparison. Set to 0 to
effectively disable depth testing."""
depthmask(mask::Bool) = ModernGL.glDepthMask(mask)

export stencilmask
"""`stencilmask(mask::Integer)`
Set the integer bit mask with which to AND the stencil buffer and fragment stencil values before comparison. Set to 0 to
effectively disable stencil testing."""
stencilmask(mask::Integer) = ModernGL.glStencilMask(UInt32(mask))
"""`stencilmask(mask::Bool) = stencilmask(mask ? 0xFF : 0x0)`
Enables or disables writing to the stencil buffer. If enabled, equivalent to `stencilmask(0xFF)`, otherwise `stencilmask(0x0)`."""
stencilmask(mask::Bool) = ModernGL.glStencilMask(mask ? UInt32(bitmax(activewindow().stencilbits)) : UInt32(0))

export depthfunc
"""`depthfunc(fn::Symbol)`
Sets one of OpenGL's static comparison functions named by `fn` for depth testing.

Available functions:

- :always - Test always passes
- :never  - Test never passes
- :<      - Fragment stencil <  stencil buffer
- :<=     - Fragment stencil <= stencil buffer
- :>      - Fragment stencil >  stencil buffer
- :>=     - Fragment stencil >= stencil buffer
- :(=)    - Fragment stencil == stencil buffer
- :!=     - Fragment stencil != stencil buffer
"""
depthfunc(fn::Symbol) = ModernGL.glDepthFunc(glfragfunc(fn))

export stencilfunc
"""`stencilfunc(fn::Symbol, ref::Integer, mask::Integer = 0xFF; face::FragFace = BothFaces)`
Sets one of OpenGL's static comparison functions named by `fn` for stencil testing. Depending on [`stencilop`](@ref),
`ref` will be written to the buffer for the current fragment. Before both the fragment stencil value and the stencil
buffer value are compared using the specified `fn`, both are AND'ed with `mask`. `face` can be either `FrontFace`,
`BackFace` or `BothFaces` (default) to apply the function to front, back, or both faces respectively.

See [`depthfunc`](@ref) for accepted `fn` values.
"""
function stencilfunc(fn::Symbol, ref::Integer, mask::Integer = 0xFF; face::FragFace = BothFaces)
    ModernGL.glStencilFuncSeparate(glfragface(face), glfragfunc(fn), ref, mask)
end

export stencilop
"""`stencilop(stencilfail::Symbol, depthfail::Symbol, pass::Symbol; face::FragFace = BothFaces)`
Specify the stencil operations for stencil test failure, depth test failure, and depth test pass. The depth test depends
on the stencil test and will not be conducted if the stencil test failed. Note that all tests are cascading in sequence.

Available operations:

- :keep                 - Do not change the stencil buffer's value.
- :zero                 - Set the stencil buffer's value to zero.
- :increment, :incr     - Increment the stencil buffer's value by one, capping at max value if it would overflow.
- :incrwrap, :incr_wrap - Increment the stencil buffer's value by one, wrapping around if it would overflow.
- :decrement, :decr     - Decrement the stencil buffer's value by one, capping at zero if it would underflow.
- :decrwrap, :decr_wrap - Decrement the stencil buffer's value by one, wrapping around if it would underflow.
- :invert               - Invert the stencil buffer's value (with respect to stencil depth set during window creation).
- :replace              - Replace stencil buffer value with fragment's stencil value set in the last [`stencilfunc`](@ref) call.
"""
function stencilop(stencilfail::Symbol, depthfail::Symbol, pass::Symbol; face::FragFace = BothFaces)
    ModernGL.glStencilOpSeparate(glfragface(face), glstencilop(stencilfail), glstencilop(depthfail), glstencilop(pass))
end


export glfragfunc
"""`glfragfunc(fn::Symbol)`
 
 Retrieves the OpenGL depth or stencil buffer comparison function by name `fn`. The OpenGL enumerator can be used aswell
 by removing the 'GL_' prefix and lowercasing the result.
 
 Available functions:
 
 * :true, :always, :tautology                  - Test always passes.
 * :false, :never, :contradict, :contradiction - Test always fails.
 * :less, :lessthan, :lt, :<                   - Fragment stencil value must be less than stencil buffer value.
 * :lequal, :lessorequal, :leq, :<=            - Fragment stencil value must be less than or equal to stencil buffer value.
 * :greater, :greaterthan, :gt, :>             - Fragment stencil value must be larger than stencil buffer value.
 * :gequal, :greaterorequal, :geq, :>=         - Fragment stencil value must be greater than or equal to stencil buffer value.
 * :equal, :eq, :(=)                           - Fragment stencil value must be equal to stencil buffer value.
 * :notequal, :neq, :!=                        - Fragment stencil value must not be equal to stencil buffer value.
 """
glfragfunc(fn::Symbol) = glfragfunc(Ident{fn}())
glfragfunc(::Ident{:always}) = ModernGL.GL_ALWAYS
glfragfunc(::Ident{:never})  = ModernGL.GL_NEVER
glfragfunc(::Ident{:<})   = ModernGL.GL_LESS
glfragfunc(::Ident{:>})   = ModernGL.GL_GREATER
glfragfunc(::Ident{:<=})  = ModernGL.GL_LEQUAL
glfragfunc(::Ident{:>=})  = ModernGL.GL_GEQUAL
glfragfunc(::Ident{:(=)}) = ModernGL.GL_EQUAL
glfragfunc(::Ident{:!=} ) = ModernGL.GL_NOTEQUAL
glfragfunc(::Ident{S}) where S = throw(ArgumentError("unknown fragment function $S - must be any of $valid_frag_funcs"))
const valid_frag_funcs = Set{Symbol}((:always, :never, :<, :>, :<=, :>=, :(=), :!=, :eq, :neq))

export glfragface
function glfragface(face::FragFace)
    if face === FrontFace
        ModernGL.GL_FRONT
    elseif face === BackFace
        ModernGL.GL_BACK
    elseif face === BothFaces
        ModernGL.GL_FRONT_AND_BACK
    else
        throw(ArgumentError("unknown fragment face $face"))
    end
end

export glstencilop
glstencilop(op::Symbol) = glstencilop(Ident{op}())
glstencilop(::Ident{:keep}) = ModernGL.GL_KEEP
glstencilop(::Ident{:zero}) = ModernGL.GL_ZERO
glstencilop(::Ident{:increment}) = ModernGL.GL_INCR
glstencilop(::Ident{:decrement}) = ModernGL.GL_DECR
glstencilop(::Ident{:wrap_increment}) = ModernGL.GL_INCR_WRAP
glstencilop(::Ident{:wrap_decrement}) = ModernGL.GL_DECR_WRAP
glstencilop(::Ident{:invert}) = ModernGL.GL_INVERT
glstencilop(::Ident{:replace}) = ModernGL.GL_REPLACE
glstencilop(::Ident{S}) where S = throw(ArgumentError("unknown stencil op $S - must be any of $valid_stencilops"))
const valid_stencilops = Set{Symbol}((:keep, :zero, :increment, :decrement, :wrap_increment, :wrap_decrement, :invert, :replace))

end # module FragFilters
