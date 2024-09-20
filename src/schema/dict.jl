"""
    DictEntry <: Schema

Keeps statistics about JSON "objects" containing key-value pairs.
"""
mutable struct DictEntry <: Schema
    const children::Dict{Symbol, Schema}
    updated::Int
end

DictEntry() = DictEntry(Dict{Symbol, Schema}(), 0)

MacroTools.@forward DictEntry.children Base.setindex!, Base.delete!, Base.get, Base.haskey,
    Base.keys, Base.length, Base.isempty

Base.getindex(e::DictEntry, k::Symbol) = e.children[k]

function update!(e::DictEntry, d::AbstractDict)
    for (k, v) in d
        k = Symbol(k)
        @try_catch_dict k begin
            if !haskey(e, k)
                e[k] = newentry(v)
            end
            update!(e[k], v)
        end
    end
    e.updated += 1
    e
end

function Base.merge!(to::DictEntry, es::DictEntry...)
    for e in es
        for (k, v) in e.children
            if haskey(to, k)
                @try_catch_dict k merge!(to[k], v)
            else
                to[k] = deepcopy(v)
            end
        end
        to.updated += e.updated
    end
    to
end

function Base.reduce(::typeof(merge), es::Vector{DictEntry})
    ks = Set{Symbol}()
    for e in es, k in keys(e)
        push!(ks, k)
    end
    ks = collect(ks)
    vs = map(ks) do k
        children = [e[k] for e in es if haskey(e, k)]
        @try_catch_dict k reduce(merge, children)
    end
    DictEntry(Dict(zip(ks, vs)), sum(e -> e.updated, es))
end

function representative_example(e::DictEntry)
    Dict(string(k) => representative_example(v) for (k, v) in e.children)
end

Base.hash(e::DictEntry, h::UInt) = hash((e.children, e.updated), h)
(e1::DictEntry == e2::DictEntry) = e1.updated == e2.updated && e1.children == e2.children
