import Pkg
Pkg.activate(".")
using KirUtil
using ModernGLAbstraction
using ModernGLAbstraction.Textures
using GLFWAbstraction

const T = Float16

vec(n) = Vec4{T}(n, n, n, n)

lifetime() do lt
  let wnd = window(:testwnd, "some window", 800, 600)
    use(wnd)
    
    data = reshape([vec(0.1i) for i in 1:16], (4, 4))
    
    tex = texture(Texture2D, data; lifetime=lt)
    dl = download_texture(T, tex)
    println(dl)
    
    close(wnd)
  end
end
