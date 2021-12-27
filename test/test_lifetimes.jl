######################################################################
# Lifetimes UTs
# -----
# Copyright (c) Kiruse 2021. Licensed under LGPL-2.1
module TestLifetimes
using Test
using GraphicsLayer.Lifetimes

function nothrow(cb)
    cb()
    true
end

struct StateError <: Exception end

mutable struct Closable
    closed::Bool
end
Closable() = Closable(false)

function Base.close(closable::Closable)
    if closable.closed
        throw(StateError())
    end
    closable.closed = true
end

@testset "Lifetimes" begin
    @testset "basic" begin
        let lt = lifetime(), cl1 = Closable(), cl2 = Closable(), cl3 = Closable()
            push!(lt, cl1)
            push!(lt, cl2)
            push!(lt, cl3)
            @test nothrow() do; close(lt) end
            @test cl1.closed && cl2.closed && cl3.closed
        end
    end
    
    @testset "double close" begin
        let closable = Closable()
            let lt = lifetime()
                push!(lt, closable)
                @assert !closable.closed
                @assert nothrow() do; close(lt) end
                @assert closable.closed
                @test   nothrow() do; close(lt) end
            end
        end
    end
    
    @testset "chained" begin
        let cl_p = Closable(), cl_i = Closable(), cl_c = Closable()
            lifetime() do lt_p
                push!(lt_p, cl_p)
                lifetime(lt_p) do lt_i
                    push!(lt_i, cl_i)
                    lifetime(lt_i) do lt_c
                        push!(lt_c, cl_c)
                    end
                    @test !cl_p.closed && !cl_i.closed && cl_c.closed
                end
                @test !cl_p.closed && cl_i.closed && cl_c.closed
            end
            @test cl_p.closed && cl_i.closed && cl_c.closed
        end
    end
end

end # module TestLifetimes
