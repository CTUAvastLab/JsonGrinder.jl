"""
    LeafEntry{T} <: Schema

Keeps statistics about scalar values of type `T` in leaves.
"""
mutable struct LeafEntry{T} <: Schema
    const counts::Dict{T, Int}
    updated::Int
end

LeafEntry(::Type{<:Real}) = LeafEntry(Dict{Real, Int}(), 0)
LeafEntry(::Type{<:AbstractString}) = LeafEntry(Dict{String, Int}(), 0)

function shorten_string(v::AbstractString)
    length(v) ≤ max_string_length() && return v
    join((v[1:max_string_length()], length(v), bytes2hex(sha1(v))), "_")
end

update!(e::LeafEntry{Real}, v::Real) = _update_leaf!(e, v)
update!(e::LeafEntry{String}, v::AbstractString) = _update_leaf!(e, shorten_string(v))

function _update_leaf!(e::LeafEntry, v)
    if length(e.counts) < max_values()
        e.counts[v] = get(e.counts, v, 0) + 1
    elseif haskey(e.counts, v)
        e.counts[v] += 1
    end
    e.updated += 1
end

function Base.merge!(to::LeafEntry{T}, es::LeafEntry{T}...) where T
    for e in es
        for (v, c) in e.counts
            if length(to.counts) < max_values()
                to.counts[v] = get(to.counts, v, 0) + c
            end
        end
        to.updated += e.updated
    end
    to
end

function Base.reduce(::typeof(merge), es::Vector{LeafEntry{T}}) where T
    counts = copy(es[1].counts)
    for i in 2:length(es)
        for (k, c) in es[i].counts
            if haskey(counts, k)
                counts[k] += c
            elseif length(counts) < max_values()
                counts[k] = c
            end
        end
    end
    LeafEntry(counts, sum(e -> e.updated, es))
end

representative_example(e::LeafEntry) = first(keys(e.counts))

Base.hash(e::LeafEntry, h::UInt) = hash((e.counts, e.updated), h)
(e1::LeafEntry == e2::LeafEntry) = e1.updated == e2.updated && e1.counts == e2.counts
