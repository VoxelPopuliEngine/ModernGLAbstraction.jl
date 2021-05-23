######################################################################
# GraphicsLayer abstract type definitions
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1

# OpenGL type abstracts
export GLType, GLPrimitive, GLAbstractPacked, GLSampler
abstract type GLType end
abstract type GLPrimitive{B} <: GLType end
abstract type GLAbstractPacked <: GLType end
abstract type GLSampler <: GLType end

# OpenGL resources
export Buffer, Shader
abstract type Buffer end
abstract type Shader end

# Texture abstracts
export Texture
abstract type Texture end
