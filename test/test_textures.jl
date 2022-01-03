######################################################################
# Unit Test for ModernGLAbstraction OpenGL buffer abstraction
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using KirUtil
using GLFWAbstraction
using ModernGLAbstraction.Textures
using Test

let wnd = window(:texture_test, "Texture Test", 960, 540)
  use(wnd)
  
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
      
      # IMPORTANT: There seems to be a bug with Int16 & (U)Int32 data types.
      # For now, what matters is UInt8, Float16, Float32.
      @testset "up/download" begin
        lifetime() do lt
          T = UInt8
          
          data = reshape(
            [Vec4{T}((i+j for j in 0:3)...) for i in 1:4:64],
            (4, 4)
          )
          
          let tex = texture(Texture2D, data; lifetime=lt)
            @test download_texture(T, tex) == data
          end
        end
        
        lifetime() do lt
          T = Float16
          
          data = reshape(
            [Vec4{T}((0.1i for _ in 0:3)...) for i in 1:16],
            (4, 4)
          )
          clipped = reshape(
            [Vec4{T}((min(c, 1.0) for c in data[y, x])...) for x in 1:4 for y in 1:4],
            (4, 4)
          )
          
          let tex = texture(Texture2D, data; lifetime=lt)
            @test isapprox(download_texture(T, tex), clipped; atol=0.01)
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
