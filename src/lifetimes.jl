######################################################################
# OpenGL Resource Lifetime Management
# -----
# Licensed under LGPL-2.1
@reexport module Lifetimes
import ..ModernGLAbstraction

const Optional{T} = Union{T, Nothing}

export LifetimeContext, Lifetime
abstract type LifetimeContext end
mutable struct Lifetime <: LifetimeContext
    parent::Optional{LifetimeContext}
    resources::Set
    terminating::Bool
end

export lifetime
function lifetime(parent::Optional{LifetimeContext} = nothing)
    inst = Lifetime(parent, Set(), false)
    if parent !== nothing
        push!(parent, inst)
    end
    inst
end
function lifetime(cb, parent::Union{Lifetime, Nothing} = nothing)
    lt = Lifetime(parent, Set(), false)
    try
        cb(lt)
    finally
        close(lt)
    end
end

function Base.close(lt::Lifetime)
    if !ModernGLAbstraction.isterminating(lt) && !ModernGLAbstraction.isterminating(lt.parent)
        close.(lt.resources)
        lt.resources = Set()
    end
end

Base.:(∈)(resource, lifetime::Lifetime) = resource ∈ lifetime.resources
Base.push!(lifetime::Lifetime, resource) = (push!(lifetime.resources, resource); lifetime)
Base.delete!(lifetime::Lifetime, resource) = (delete!(lifetime.resources, resource); lifetime)
Base.length(lifetime::Lifetime) = length(lifetime.resources)

end # module Lifetime
import .Lifetimes

terminate(lt::Lifetimes.Lifetime) = (lt.terminating = true; lt)
isterminating(::Nothing) = false
isterminating(lt::Lifetimes.Lifetime) = lt.terminating
