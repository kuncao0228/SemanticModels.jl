module Dubstep

using Cassette
using LinearAlgebra
export construct, TracedRun, trace, TraceCtx, LPCtx, replacenorm,
    GraftCtx, replacefunc

function construct(T::Type, args...)
    @info "constructing a model $T"
    return T(args...)
end

Cassette.@context TraceCtx

"""    TraceCtx

builds dynamic analysis traces of a model for information extraction
"""
TraceCtx

function Cassette.overdub(ctx::TraceCtx, args...)
    subtrace = Any[]
    push!(ctx.metadata, args => subtrace)
    if Cassette.canrecurse(ctx, args...)
        newctx = Cassette.similarcontext(ctx, metadata = subtrace)
        return Cassette.recurse(newctx, args...)
    else
        return Cassette.fallback(ctx, args...)
    end
end

function Cassette.overdub(ctx::TraceCtx, f::typeof(Base.vect), args...)
    @info "constructing a vector"
    push!(ctx.metadata, (f, args))
    return Cassette.fallback(ctx, f, args...)
end

function Cassette.overdub(ctx::TraceCtx, f::typeof(Core.apply_type), args...)
    # @info "applying a type $(args)"
    push!(ctx.metadata, (f, args))
    return Cassette.fallback(ctx, f, args...)
end

# TODO: support calls like construct(T, a, f(b))
function Cassette.overdub(ctx::TraceCtx, f::typeof(construct), args...)
    @info "constructing with type $f"
    push!(ctx.metadata, (f, args))
    y = Cassette.fallback(ctx, f, args...)
    @info "constructed model: $y"
    return y
end

"""    TracedRun{T,V}

captures the dataflow of a code execution. We store the trace and the value.

see also `trace`.
"""
struct TracedRun{T,V}
    trace::T
    value::V
end

"""    trace(f)

run the function f and return a TracedRun containing the trace and the output.
"""
function trace(f::Function)
    trace = Any[]
    val = Cassette.recurse(TraceCtx(metadata=trace), f)
    return TracedRun(trace, val)
end



Cassette.@context LPCtx

"""    LPCtx

replaces all calls to `LinearAlgebra.norm` with a different `p`.

This context is useful for modifying statistical codes or machine learning regularizers.
"""
LPCtx

function Cassette.overdub(ctx::LPCtx, args...)
    if Cassette.canrecurse(ctx, args...)
        newctx = Cassette.similarcontext(ctx, metadata = ctx.metadata)
        return Cassette.recurse(newctx, args...)
    else
        return Cassette.fallback(ctx, args...)
    end
end

function Cassette.overdub(ctx::LPCtx, f::typeof(norm), arg, power)
    p = get(ctx.metadata, power, power)
    return f(arg, p)
end

"""    replacenorm(f::Function, d::AbstractDict)

run f, but replace every call to norm using the mapping in d.
"""
function replacenorm(f::Function, d::AbstractDict)
    ctx = LPCtx(metadata=d)
    return Cassette.recurse(ctx, f)
end

Cassette.@context GraftCtx


"""    GraftCtx

grafts an expression from one simulation onto another

This context is useful for modifying simulations by changing out components to add features

see also: [`Dubstep.LPCtx`](@ref)
"""
GraftCtx

function Cassette.overdub(ctx::GraftCtx, f, args...)
    if Cassette.canrecurse(ctx, f, args...)
        newctx = Cassette.similarcontext(ctx, metadata = ctx.metadata)
        return Cassette.recurse(newctx, f, args...)
    else
        return Cassette.fallback(ctx, f, args...)
    end
end


"""    replacefunc(f::Function, d::AbstractDict)

run f, but replace every call to f using the context GraftCtx.
in order to change the behavior you overload overdub based on the context.
Metadata used to influence the context is stored in d.

see also: `bin/graft.jl` for an example.
"""
function replacefunc(f::Function, d::AbstractDict)
    ctx = GraftCtx(metadata=d)
    return Cassette.recurse(ctx, f)
end

end #module

