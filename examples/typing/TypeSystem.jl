# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.3'
#       jupytext_version: 0.8.6
#   kernelspec:
#     display_name: Julia 1.0.3
#     language: julia
#     name: julia-1.0
# ---

using Cassette;
using DifferentialEquations;

# +
# define the context we will use
ctx = Cassette.@context typCtx

# add boilerplate for functionality
function Cassette.overdub(ctx::typCtx, args...)
    println(typeof.(args))
    if Cassette.canrecurse(ctx, args...)
        newctx = Cassette.similarcontext(ctx, metadata = ctx.metadata)
        return Cassette.recurse(newctx, args...)
    else
        return Cassette.fallback(ctx, args...)
    end
end
    
function Cassette.canrecurse(ctx::typCtx,::typeof(ODEProblem), args...)
    return false
end

function Cassette.canrecurse(ctx::typCtx,::typeof(Base.vect), args...)
    return false
end
    
function Cassette.overdub(ctx::typCtx,::typeof(ODEProblem), args...)
    return (src=args[2:end],dst=nothing,func=typeof(ODEProblem))
end

# +
function main()
    
    # define our ode
    function sir_ode(du, u, p, t)  
        #Infected per-Capita Rate
        β = p[1]
        #Recover per-capita rate
        γ = p[2]
        #Susceptible Individuals
        S = u[1]
        #Infected by Infected Individuals
        I = u[2]

        du[1] = -β * S * I
        du[2] = β * S * I - γ * I
        du[3] = γ * I
    end

    #Pram = (Infected Per Capita Rate, Recover Per Capita Rate)
    pram = [0.1,0.05]
    #Initial Prams = (Susceptible Individuals, Infected by Infected Individuals)
    init = [0.99,0.01,0.0]
    tspan = (0.0,200.0)
    
    # create a var to our problem
    sir_prob = ODEProblem(sir_ode, init, tspan, pram)
    
end
# -

Cassette.overdub(typCtx(),main)


