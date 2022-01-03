######################################################################
# Low level abstraction of OpenGL's glDraw* methods.
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
import ModernGL

export draw

"""`ModernGLAbstraction.glprimitive(mode::Symbol)`
 
 Retrieves the OpenGL enumerator representing the specified draw mode.
 
 The following draw modes are available:
 
 - :points
 - :lines
 - :linestrip
 - :linestrip_adjacency
 - :tris, :triangles
 - :tristrip, :trianglestrip
 - :tristrip_adjacency, :trianglestrip_adjacency
 - :trifan, :trianglefan
 - :quads
 - :quadstrip
 """
function glprimitive(mode::Symbol)
    if mode === :points
        ModernGL.GL_POINTS
    elseif mode === :lines
        ModernGL.GL_LINES
    elseif mode === :linestrip
        ModernGL.GL_LINE_STRIP
    elseif mode === :linestrip_adjacency
        ModernGL.GL_LINE_STRIP_ADJACENCY
    elseif mode ∈ (:tris, :triangles)
        ModernGL.GL_TRIANGLES
    elseif mode ∈ (:tristrip, :trianglestrip)
        ModernGL.GL_TRIANGLE_STRIP
    elseif mode ∈ (:trifan, :trianglefan)
        ModernGL.GL_TRIANGLE_FAN
    elseif mode ∈ (:tristrip_adjacency, :trianglestrip_adjacency)
        ModernGL.GL_TRIANGLE_STRIP_ADJACENCY
    elseif mode === :quads
        ModernGL.GL_QUADS
    elseif mode === :quadstrip
        ModernGL.GL_QUAD_STRIP
    else
        throw(ArgumentError("Unknown primitive type $mode"))
    end
end

"""`ModernGLAbstraction.draw(va::ModernGLAbstraction.VertexArray, prim::Symbol, count::Integer; first::Integer = 1)`
 
 Issues the GPU to render the primitives represented by `va` on screen as `count` OpenGL primitives of type `prim`. An
 offset to the first primitive to draw can be specified. The last primitive drawn will be `first+count`.
 
 For a list of possible primitives, see [`ModernGLAbstraction.glprimitive`](@ref)."""
function draw(va::VertexArray, mode::Symbol, count::Integer; first::Integer = 1)
    use(va)
    ModernGL.glDrawArrays(glprimitive(mode), first-1, count) # first-1 because Julia starts indexing at 1, but OpenGL starts at 0
    checkglerror()
end
