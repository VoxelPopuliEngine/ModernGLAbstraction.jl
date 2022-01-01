######################################################################
# Unit Test for ModernGLAbstraction OpenGL buffer abstraction
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
using ExtraFun
using GLFWAbstraction
using ModernGLAbstraction
using Test

@testset "GPU Buffers" begin
    @testset "ArrayBuffer" begin
        let wnd = window(:arraybuffer_test, "ArrayBuffer Test", 960, 540)
            lifetime() do lt
                use(wnd)
                wnd.visible = false
                let data1 = UInt32[24, 69, 420], data2 = UInt32[69, 420, 42069], buff = buffer(ArrayBuffer, data1, :static, :read; lifetime=lt)
                    bytes1 = ModernGLAbstraction.bytes(data1)
                    bytes2 = ModernGLAbstraction.bytes(data2)
                    
                    @test size(buff) == 3sizeof(UInt32)
                    
                    @test buffer_download(buff, size(buff)) == bytes1
                    
                    buffer_update(buff, data2)
                    @test buffer_download(buff, size(buff)) == bytes2
                end
            end
            close(wnd)
        end
    end
    
    # TODO: @testset ArrayElementBuffer
    # TODO: @testset TextureBufferType
    # TODO: @testset UniformBufferType
end
