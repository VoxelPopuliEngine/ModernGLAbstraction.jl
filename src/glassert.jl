######################################################################
# Utility Macro to assert the state of OpenGL & throw appropriate
# error messages.
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using ModernGL
using ExtraFun: decamelcase

macro glassert(blk::Expr)
    @assert blk.head === :block
    replace!(expr -> transmute_glerror(:err, expr), blk.args)
    prepend!(blk.args, (:(err = ModernGL.glGetError()),))
    append!(blk.args, (:(err !== ModernGL.GL_NO_ERROR && throw(OpenGLError(err))),))
    blk
end

transmute_glerror(::Symbol, node::LineNumberNode) = node
function transmute_glerror(errname::Symbol, expr::Expr)
    @assert expr.head === :call && expr.args[1] === :(=>) && expr.args[2] isa Symbol
    errvalue = Expr(:., :ModernGL, QuoteNode(Symbol("GL_" * decamelcase(string(expr.args[2]), uppercase=true))))
    :($errname === $errvalue && throw($(esc(expr.args[3]))))
end
