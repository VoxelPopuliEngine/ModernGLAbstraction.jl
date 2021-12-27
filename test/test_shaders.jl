######################################################################
# Shaders UTs
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
module TestShaders
using Test
using ExtraFun
using GLFWAbstraction
using Main: nothrow
using GraphicsLayer
using GraphicsLayer: StateError
using GraphicsLayer.Shaders: findattribute, finduniform
import ModernGL

const vsh_src_basic = """
    #version 330

    in vec2 coords;
    in vec3 color;
    out vec3 vColor;

    void main() {
        gl_Position = vec4(coords, 0, 1);
        vColor = color;
    }
"""

const fsh_src_basic = """
    #version 330
    
    in vec3 vColor;
    out vec3 fragColor;
    
    void main() {
        fragColor = vColor;
    }
"""

const vsh_src_uniforms = """
    #version 330

    in vec3 coords;
    out vec3 vCoords;
    
    uniform bool trigger;
    uniform vec3 vertoffset;
    uniform mat4[2] transform;

    void main() {
        gl_Position = vec4(coords + vertoffset, 1) * transform[trigger ? 1 : 0];
    }
"""

const fsh_src_uniforms = """
    #version 330
    
    in vec3 vCoords;
    
    uniform bool trigger;
    uniform float alpha;
    uniform vec3[2] colors;
    
    out vec3 fragColor;

    void main() {
        if (trigger) {
            fragColor = mix(colors[0], colors[1], alpha);
        }
        else {
            fragColor = colors[0] * colors[1];
        }
    }
"""

wnd = window(:test_shaders_basic, "Shaders UT", 960, 540)
use(wnd)

@testset "Shaders" begin
    @testset "vertex & fragment" begin
        let vsh = shader(VertexShader, vsh_src_basic; isfilepath=false), fsh = shader(FragmentShader, fsh_src_basic; isfilepath=false)
            @test vsh.type == ModernGL.GL_VERTEX_SHADER
            @test fsh.type == ModernGL.GL_FRAGMENT_SHADER
            
            @test vsh.source_length == length(vsh_src_basic) && fsh.source_length == length(fsh_src_basic)
            @test vsh.source == vsh_src_basic && fsh.source == fsh_src_basic
            
            @test vsh.compiled
            @test fsh.compiled
            @test !vsh.deleted && !fsh.deleted
            
            @test nothrow() do; vsh.log_length; vsh.log end
            @test nothrow() do; fsh.log_length; fsh.log end
            
            @test isvalid(vsh) && isvalid(fsh)
            
            @test nothrow() do; close(vsh) end
            @test nothrow() do; close(fsh) end
            @test !isvalid(vsh) && !isvalid(fsh)
        end
        
        swapbuffers(wnd)
    end
    
    # TODO: Test ComputeShaders, GeometryShaders, Tessellation Shaders
end

@testset "Programs" begin
    @testset "basic" begin
        let vsh = shader(VertexShader, vsh_src_basic; isfilepath=false), fsh = shader(FragmentShader, fsh_src_basic; isfilepath=false)
            let prog = program(vsh, fsh)
                @test prog.linked
                @test !prog.deleted
                @test nothrow() do; prog.validated end
                @test isvalid(prog)
                
                @test nothrow() do; prog.log_length; prog.log end
                @test nothrow() do; size(prog); prog.binary end
                @test nothrow() do; prog.max_attribute_name_length; prog.max_uniform_name_length end
                @test_throws StateError prog.geometry_input_type
                @test_throws StateError prog.geometry_output_type
                
                @test count(prog, :atomic_counter_buffers) == 0
                @test count(prog, :attributes) == 2
                @test count(prog, :shaders) == 0
                @test count(prog, :uniforms) == 0
                @test_throws StateError count(prog, :geometry_vertices)
                
                @test findattribute(prog, "coords") == 0
                @test findattribute(prog, "color") == 1
                @test findattribute(prog, "coords") == findattribute(prog, :coords) && findattribute(prog, "color") == findattribute(prog, :color)
            end
        end
    end
    
    @testset "uniforms" begin
        @testset "simple" begin let
            vsh = shader(VertexShader, vsh_src_uniforms; isfilepath=false)
            fsh = shader(FragmentShader, fsh_src_uniforms; isfilepath=false)
            prog = program(vsh, fsh)
            @assert isvalid(prog)
            
            @test count(prog, :uniforms) == 5
            
            @test all(isvalid.((
                Uniform(Bool,    prog, :trigger),
                Uniform(Vec3f,   prog, :vertoffset),
                Uniform(Mat4f,   prog, :transform),
                Uniform(Float32, prog, :alpha),
                Uniform(Vec3f,   prog, :colors),
            )))
        end end
    end
end

close(wnd)

end # module TestShaders
