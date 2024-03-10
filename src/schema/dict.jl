"""
    DictEntry <: AbstractJSONEntry

Keeps statistics about JSON "objects" containing key-value pairs:
- statistics of all individual values
- how many times the entry was updated
"""
mutable struct DictEntry <: AbstractJSONEntry
    const children::Dict{Symbol, AbstractJSONEntry}
    updated::Int
end

DictEntry() = DictEntry(Dict{Symbol, AbstractJSONEntry}(), 0)

MacroTools.@forward DictEntry.children Base.getindex, Base.setindex!, Base.get, Base.haskey,
    Base.keys, Base.length, Base.isempty

macro try_catch_dict_entry(ex, k)
    quote
        try
            $(esc(ex))
        catch e
            if e isa InconsistentSchema
                push!(e.path, "[:" * string($(esc(k))) * "]")
            end
            rethrow(e)
        end
    end
end

function update!(e::DictEntry, d::AbstractDict{<:AbstractString})
    for (k, v) in d
        k = Symbol(k)
        if haskey(e, k)
            @try_catch_dict_entry update!(e[k], v) k
        else
            e[k] = newentry(v)
        end
    end
    e.updated += 1
end

function Base.merge!(to::DictEntry, es::DictEntry...)
    for e in es
        for (k, v) in e.children
            if haskey(to, k)
                @try_catch_dict_entry merge!(to[k], v) k
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
        @try_catch_dict_entry reduce(merge, children) k
    end
    DictEntry(Dict(zip(ks, vs)), sum(e -> e.updated, es))
end

Base.hash(e::DictEntry, h::UInt) = hash((e.children, e.updated), h)
(e1::DictEntry == e2::DictEntry) = e1.updated == e2.updated && e1.children == e2.children
