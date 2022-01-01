######################################################################
# LowLevel abstraction of OpenGL shaders.
# -----
# Copyright (c) Kiruse 2021. Licensed under LPGP-2.1
@reexport module Shaders
import ExtraFun
import ModernGL
using ExtraFun: Ident, decamelcase
using GenerateProperties
using ..ModernGLAbstraction
using ..ModernGLAbstraction: glenum, glid, glstate, StateError, ImplementationError, @glassert

macro generate_shader_types(blk::Expr)
    @assert blk.head === :block
    
    enums = Expr(:macrocall, Symbol("@enum"), __source__, :ShaderType)
    res = Expr(:block, enums)
    
    for expr ∈ blk.args
        if expr isa LineNumberNode
            push!(res.args, expr)
            continue
        end
        
        if expr isa Symbol
            var   = expr
            enum  = Symbol("$(expr)Type")
            value = Expr(:., :ModernGL, QuoteNode(Symbol("GL_" * decamelcase(string(expr), uppercase=true))))
        else
            @assert expr.head === :call && expr.args[1] === :(=>)
            var   = expr.args[2]
            enum  = Symbol("$(expr.args[2])Type")
            value = Expr(:., :ModernGL, QuoteNode(expr.args[3]))
        end
        
        push!(enums.args, enum)
        push!(res.args, :(export $var))
        push!(res.args, :(const $var = GLShader{$enum}))
        push!(res.args, :(ModernGLAbstraction.glenum(::Type{GLShader{$enum}}) = $value))
    end
    
    return esc(res)
end


export GLShader
struct GLShader{T} <: Shader
    glid::UInt32
    function GLShader{T}(glid) where T
        @assert T isa ShaderType
        new(glid)
    end
end
@generate_shader_types begin
    VertexShader
    FragmentShader
    GeometryShader
    ComputeShader
    TessellationControlShader => GL_TESS_CONTROL_SHADER
    TessellationEvaluationShader => GL_TESS_EVALUATION_SHADER
end

# ShaderType as defined in Julia. For shader type as officially registered with OpenGL, get `type` virtual property.
ShaderType(::GLShader{T}) where T = (@assert(T isa ShaderType); T)

@generate_properties GLShader begin
    @get compiled = parameter(self, ModernGL.GL_COMPILE_STATUS) != 0
    @get deleted  = parameter(self, ModernGL.GL_DELETE_STATUS) != 0
    
    @get type = parameter(self, ModernGL.GL_SHADER_TYPE) # Shader type as officially registered with OpenGL. Usually, ShaderType(shdr) should suffice, however.
    
    @get log_length    = max(0, parameter(self, ModernGL.GL_INFO_LOG_LENGTH) - 1)
    @get source_length = max(0, parameter(self, ModernGL.GL_SHADER_SOURCE_LENGTH) - 1)
    
    @get log = get_info_log(self)
    @get source = get_shader_source(self)
end

export Program
"""`Program` resembles a shader program. By itself, it provides only an abstraction of program related OpenGL functions."""
struct Program
    glid::UInt32
end

@generate_properties Program begin
    @get deleted   = parameter(self, ModernGL.GL_DELETE_STATUS) != 0
    @get linked    = parameter(self, ModernGL.GL_LINK_STATUS) != 0
    @get validated = parameter(self, ModernGL.GL_VALIDATE_STATUS) != 0
    
    @get log_length = parameter(self, ModernGL.GL_INFO_LOG_LENGTH)
    @get max_attribute_name_length = parameter(self, ModernGL.GL_ACTIVE_ATTRIBUTE_MAX_LENGTH)
    @get max_uniform_name_length   = parameter(self, ModernGL.GL_ACTIVE_UNIFORM_MAX_LENGTH)
    
    @get geometry_input_type  = parameter(self, ModernGL.GL_GEOMETRY_INPUT_TYPE)
    @get geometry_output_type = parameter(self, ModernGL.GL_GEOMETRY_OUTPUT_TYPE)
    
    @get log = get_info_log(self)
    @get binary = get_program_binary(self)
end

Base.count(prog::Program, prop::Symbol) = count(prog, Ident{prop}())
Base.count(prog::Program, ::Ident{:atomic_counter_buffers}) = parameter(prog, ModernGL.GL_ACTIVE_ATOMIC_COUNTER_BUFFERS)
Base.count(prog::Program, ::Ident{:attributes}) = parameter(prog, ModernGL.GL_ACTIVE_ATTRIBUTES)
Base.count(prog::Program, ::Ident{:shaders})    = parameter(prog, ModernGL.GL_ATTACHED_SHADERS)
Base.count(prog::Program, ::Ident{:uniforms})   = parameter(prog, ModernGL.GL_ACTIVE_UNIFORMS)
Base.count(prog::Program, ::Ident{:geometry_vertices}) = parameter(prog, ModernGL.GL_GEOMETRY_VERTICES_OUT)

Base.size(prog::Program) = parameter(prog, ModernGL.GL_PROGRAM_BINARY_LENGTH)


export shader
"""`shader(::Type{<:Shader}, src::AbstractString; isfilepath::Bool = true)`
Create a new shader of given type. If `isfilepath` is true (default), `src` is treated as the path to a file containing
the source code of the shader. Otherwise, `src` is treated as its source code directly.

See also [`VertexShader`](@ref), [`FragmentShader`](@ref), [`GeometryShader`](@ref), [`ComputeShader`](@ref)."""
function shader(T::Type{<:Shader}, src::AbstractString; isfilepath::Bool = true)
    shdr = shader(T)
    if isfilepath
        src = open(src, "r") do f
            read(f, String)
        end
    end
    shader_source(shdr, src)
    shader_compile(shdr)
    return shdr
end

function shader(T::Type{<:GLShader})
    shdr = T(ModernGL.glCreateShader(glenum(T)))
    @glassert begin
        InvalidEnum => ImplementationError("invalid shader type")
    end
    return shdr
end

function shader_source(shdr::Shader, src::AbstractString)
    sources = [pointer(src)]
    lengths = [length(src)]
    ModernGL.glShaderSource(glid(shdr), length(sources), pointer(sources), pointer(lengths))
    @glassert begin
        InvalidValue => ImplementationError("invalid shader glid")
        InvalidOperation => ImplementationError("not a shader object")
    end
    nothing
end

function shader_compile(shdr::Shader)
    ModernGL.glCompileShader(glid(shdr))
    if !shdr.compiled
        throw(StateError(shdr, "failed to compile: " * shdr.log))
    end
    nothing
end


export program
"""`program(shaders::Shader..., autodelete_shaders = true)`
Create a new program, attach given `shaders`, and link. If `autodelete_shaders` is true, `shaders` will be deleted once
successfully linked."""
function program(shaders::Shader...; autodelete_shaders::Bool = true)
    prog = program()
    for shdr in shaders
        program_attach(prog, shdr)
    end
    
    program_link(prog)
    println()
    
    for shdr in shaders
        program_detach(prog, shdr)
        if autodelete_shaders
            close(shdr)
        end
    end
    
    return prog
end

"""`program(binary, format)`
Create a program from precompiled binary code with given format. Both can be retrieved in a tuple using `program.binary`
after a program has been successfully linked."""
program(binary, format::ModernGL.GLenum) = program(collect(binary), format)
function program(binary::Vector{UInt8}, format::ModernGL.GLenum)
    prog = program()
    ModernGL.glProgramBinary(prog.glid, format, pointer(binary), length(binary))
    @glassert begin
        InvalidEnum => ArgumentError("invalid binary format")
        InvalidOperation => ImplementationError("invalid program glid")
    end
    prog
end

"""`program()`
Create a new, empty, unlinked program."""
function program()
    prog = Program(ModernGL.glCreateProgram())
    if prog.glid == 0
        error("failed to create program")
    end
    return prog
end

export active_program
function active_program()
    prog = Program(glstate(Int32, ModernGL.GL_CURRENT_PROGRAM))
    if prog.glid == 0
        throw(StateError("no active program"))
    end
    prog
end

function program_attach(prog::Program, shdr::Shader)
    ModernGL.glAttachShader(glid(prog), glid(shdr))
    try
        @glassert begin
            InvalidValue => ImplementationError("invalid program or shader glid")
            InvalidOperation => begin
                if ModernGL.glIsProgram(prog.glid) == 0
                    ImplementationError("not a program object")
                elseif ModernGL.glIsShader(shdr.glid) == 0
                    ImplementationError("not a shader object")
                else
                    StateError(prog, "shader already attached")
                end
            end
        end
    catch ex
        if !isa(ex, StateError)
            rethrow()
        end
    end
    nothing
end

function program_link(prog::Program)
    ModernGL.glLinkProgram(glid(prog))
    @glassert begin
        InvalidValue => ImplementationError("invalid program glid")
        InvalidOperation => begin
            if ModernGL.glIsProgram(prog.glid) == 0
                ImplementationError("not a program object")
            else
                StateError("transform feedback enabled")
            end
        end
    end
    
    if !prog.linked
        throw(StateError(prog, "failed to link: " * prog.log))
    end
end

function program_validate(prog::Program)
    ModernGL.glValidateProgram(prog.glid)
    @glassert begin
        InvalidValue => ImplementationError("invalid program glid")
        InvalidOperation => ImplementationError("not a program object")
    end
end

function program_detach(prog::Program, shdr::Shader)
    ModernGL.glDetachShader(glid(prog), glid(shdr))
    try
        @glassert begin
            InvalidValue => ImplementationError("invalid program or shader glid")
            InvalidOperation => begin
                if ModernGL.glIsProgram(prog.glid) == 0
                    ImplementationError("not a program object")
                elseif ModernGL.glIsShader(shdr.glid) == 0
                    ImplementationError("not a shader object")
                else
                    StateError("shader not attached")
                end
            end
        end
    catch ex
        if !isa(ex, StateError)
            rethrow()
        end
    end
    nothing
end


"""`findattribute(prog::Program, name)`
Find the named attribute's location within the shader. Returns -1 if no such attribute exists, or is otherwise unretrievable."""
findattribute(prog::Program, name) = findattribute(prog, string(name))
function findattribute(prog::Program, name::String)
    loc = ModernGL.glGetAttribLocation(prog.glid, pointer(string(name)))
    @glassert begin
        InvalidValue => ImplementationError("invalid program glid")
        InvalidOperation => begin
            if !prog.linked
                StateError(prog, "not successfully linked")
            elseif ModernGL.glIsProgram(prog.glid) == 0
                ImplementationError("not a program object")
            else
                InvalidOperationGLError()
            end
        end
    end
    loc
end

"""`finduniform(prog::Program, name)`
Find the named uniform's location within the program. Returns -1 if no such uniform exists, or is otherwise unretrievable."""
finduniform(prog::Program, name) = finduniform(prog, string(name))
function finduniform(prog::Program, name::String)
    loc = ModernGL.glGetUniformLocation(prog.glid, pointer(name))
    @glassert begin
        InvalidValue => ImplementationError("invalid program glid")
        InvalidOperation => begin
            if !prog.linked
                StateError(prog, "not successfully linked")
            elseif ModernGL.glIsProgram(prog.glid) == 0
                ImplementationError("not a program object")
            else
                InvalidOperationGLError()
            end
        end
    end
    loc
end


function ExtraFun.use(prog::Program)
    !isvalid(prog) && throw(StateError(prog, "invalid shader program"))
    
    ModernGL.glUseProgram(glid(prog))
    @glassert begin
        InvalidValue => ImplementationError("invalid shader glid")
        # InvalidOperation
    end
    prog
end

function Base.close(prog::Program)
    if isvalid(prog)
        ModernGL.glDeleteProgram(glid(prog))
        @glassert begin
            InvalidValue => ImplementationError("invalid glid")
        end
    end
    nothing
end
function Base.close(shdr::Shader)
    if isvalid(shdr)
        ModernGL.glDeleteShader(glid(shdr))
        @glassert begin
            InvalidValue => ImplementationError("invalid glid")
        end
    end
    nothing
end

Base.bind(prog::Program, attr, location::Integer) = bind(prog, string(attr), location)
function Base.bind(prog::Program, attr::String, location::Integer)
    if prog.glid == 0 || ModernGL.glIsProgram(prog.glid) == 0
        throw(StateError("invalid program glid"))
    end
    
    ModernGL.glBindAttribLocation(prog.glid, UInt32(location), pointer(attr))
    @glassert begin
        InvalidValue => begin
            if location > ModernGL.GL_MAX_VERTEX_ATTRIBS
                DomainError(:location, "location too large: $location > $(ModernGL.GL_MAX_VERTEX_ATTRIBS)")
            else
                ImplementationError("invalid program glid")
            end
        end
        InvalidOperation => begin
            if attr[1:3] === "gl_"
                ArgumentError("reserved attribute prefix 'gl_'")
            else
                ImplementationError("not a program object")
            end
        end
    end
    
    return prog
end

Base.isvalid(prog::Program)  = prog.glid != 0 && ModernGL.glIsProgram(prog.glid) && prog.linked && !prog.deleted
Base.isvalid(shdr::GLShader) = shdr.glid != 0 && ModernGL.glIsShader(shdr.glid) && shdr.compiled && !shdr.deleted


function parameter(prog::Program, param::UInt32)
    ref = Ref{ModernGL.GLint}()
    ModernGL.glGetProgramiv(prog.glid, param, ref)
    @glassert begin
        InvalidEnum  => ArgumentError("illegal parameter")
        InvalidValue => ImplementationError("invalid program glid")
        InvalidOperation => begin
            if !ModernGL.glIsProgram(prog.glid)
                ImplementationError("glid not a program")
            elseif param ∈ (ModernGL.GL_GEOMETRY_VERTICES_OUT, ModernGL.GL_GEOMETRY_INPUT_TYPE, ModernGL.GL_GEOMETRY_OUTPUT_TYPE)
                StateError("program might not contain a geometry shader")
            else
                InvalidOperationGLError()
            end
        end
    end
    ref[]
end

function parameter(shdr::GLShader, param::UInt32)
    ref = Ref{ModernGL.GLint}()
    ModernGL.glGetShaderiv(shdr.glid, param, ref)
    @glassert begin
        InvalidEnum  => ArgumentError("illegal parameter")
        InvalidValue => ImplementationError("invalid shader glid")
        InvalidOperation => ImplementationError("not a shader")
    end
    ref[]
end

function get_info_log(prog::Program)
    loglen = prog.log_length
    res = zeros(ModernGL.GLchar, loglen)
    ModernGL.glGetProgramInfoLog(glid(prog), loglen, C_NULL, pointer(res))
    @glassert begin
        InvalidValue => ImplementationError("invalid program glid")
        InvalidOperation => ImplementationError("not a program object")
    end
    return unsafe_string(pointer(res), loglen)
end

function get_info_log(shdr::Shader)
    loglen = shdr.log_length
    res = zeros(ModernGL.GLchar, loglen)
    ModernGL.glGetShaderInfoLog(glid(shdr), loglen+1, C_NULL, pointer(res))
    @glassert begin
        InvalidValue => ImplementationError("invalid shader glid")
        InvalidOperation => ImplementationError("not a shader object")
    end
    return unsafe_string(pointer(res), loglen)
end

"""`get_program_binary(prog::Program)`
Get the compiled binary code of the program for later reuse. Returns a tuple of `Vector{UInt8}` containing the program
bytes and the binary format. Both must be provided to [`program`](@ref)."""
function get_program_binary(prog::Program)
    let size = size(prog)
        buffer = zeros(UInt8, size)
        format = Ref{ModernGL.GLenum}()
        ModernGL.glGetProgramBinary(prog.glid, size, C_NULL, format, pointer(buffer))
        return buffer, format
    end
end

"""`get_shader_source(shader)`
Get the combined source code as passed into OpenGL using [`shader_source`](@ref) and/or `ModernGL.glShaderSource`."""
function get_shader_source(shdr::GLShader)
    srclen = shdr.source_length
    srcbytes = zeros(UInt8, srclen)
    ModernGL.glGetShaderSource(glid(shdr), srclen+1, C_NULL, pointer(srcbytes))
    @glassert begin
        InvalidValue => ImplementationError("invalid shdr glid, or srclen($srclen) < 0")
        InvalidOperation => ImplementationError("not a shader object")
    end
    return unsafe_string(pointer(srcbytes), srclen)
end

end # module Shaders
