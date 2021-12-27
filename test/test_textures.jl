######################################################################
# Unit Test for GraphicsLayer OpenGL buffer abstraction
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using ExtraFun
using GLFWAbstraction
using GraphicsLayer.Textures
using Test

let wnd = window(:texture_test, "Texture Test", 960, 540)
  @testset "Textures" begin
    @testset "Texture2D" begin
      @testset "basic" begin
        lifetime() do lt
          @test_throws TypeError texture(Texture2DBase; lifetime=lt) # must be concrete type
          @test texture(Texture2DBase{4}; lifetime=lt) isa Texture2DBase
          @test texture(Texture2D; lifetime=lt) isa Texture2DBase{4}
          
          @test texture_channels(Texture2DBase{4}) == 4
          @test texture_channels(Texture2DBase{1}) == 1
          @test texture_channels(Texture2D) == 4
          @test texture_channels(DSTexture) == 2
          @test texture_channels(texture(Texture2DBase{4}; lifetime=lt)) == 4
          @test texture_channels(texture(Texture2DBase{1}; lifetime=lt)) == 1
          @test texture_channels(texture(Texture2D; lifetime=lt)) == 4
          @test texture_channels(texture(DSTexture; lifetime=lt)) == 2
        end
      end
      
      @testset "up/download" begin
        lifetime() do lt
          raw = reshape(collect(Int32, 1:64), (4, 4, 4))
          data = reshape([
            Vec4((raw[x, y, z] for z ∈ 1:4)...) for y ∈ 1:4 for x ∈ 1:4
          ], (4, 4))
          
          let tex = texture(Texture2D, data; lifetime=lt)
            
          end
        end
      end
      
      @testset "screenshot" begin
        # TODO: depends on draws submodule
      end
    end
    
    @testset "DepthStencilTexture" begin
      
    end
  end
end
    