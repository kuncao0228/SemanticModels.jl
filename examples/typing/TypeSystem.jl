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

# The model that we would like to edit.

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
    solution = solve(sir_prob)
    
end
# -

# Define a data structure that we will use to collect the edge information we would like to have.

""" 
trace_collector(func, args, ret, subtrace)

a structure to hold metadata for recursive type information
"""
mutable struct trace_collector
    func
    args
    ret
    subtrace::Vector{trace_collector}
end

"""    trace_collect(func, args...)

    creates a new trace_collector logging the input argument types and function name. You have to set the `ret` field after you call the function. 
    This constructor creates the subtrace field for use in Cassette.similarcontext.
"""
function trace_collect(func, args...)
    return trace_collector(func, typeof.(args), nothing, trace_collector[])
end

function Cassette.canrecurse(ctx::typCtx,::typeof(ODEProblem),args...)
    return false
end

function Cassette.canrecurse(ctx::typCtx,::typeof(Base.vect),args...)
    return false
end



# define our context
ctx = Cassette.@context typCtx

# boilerplate for functionality
function Cassette.overdub(ctx::typCtx, args...)
    @show args
    @show ctx.metadata
    if Cassette.canrecurse(ctx, args...)
        newctx = Cassette.similarcontext(ctx, metadata = ctx.metadata)
        return Cassette.recurse(newctx, args...)
    else
        println("Fallback loop")
        return Cassette.fallback(ctx, args...)
    end
end

function Cassette.overdub(ctx::typCtx,::typeof(ODEProblem),args...)
    println("ODE Formulation:")
    println( (src=typeof(args[2:end]),dst=nothing,func=typeof(ODEProblem)) )
    return ODEProblem(args...) 
end

function Cassette.overdub(ctx::typCtx,::typeof(solve),args...)
    sol = solve(args...)
    println("Solver:")
    println((src=typeof(ODEProblem),dst=typeof((sol.t,sol.u)),func=typeof(solve)))
end


Cassette.overdub(typCtx(),main)