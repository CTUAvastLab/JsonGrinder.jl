"""
    ArrayEntry <: Schema

Keeps statistics about an "array" entry in JSONs.
"""
mutable struct ArrayEntry <: Schema
    items::Union{Nothing, Schema}
    const lengths::Dict{Int, Int}
    updated::Int
end

ArrayEntry() = ArrayEntry(nothing, Dict{Int,Int}(), 0)

function update!(e::ArrayEntry, V::AbstractVector)
    l = length(V)
    if isnothing(e.items) && !isempty(V)
        @try_catch_array e.items = newentry(first(V))
    end
    for v in V
        @try_catch_array update!(e.items, v)
    end
    e.lengths[l] = get(e.lengths, l, 0) + 1
    e.updated += 1
    e
end

function Base.merge!(to::ArrayEntry, es::ArrayEntry...)
    for e in es
        if !isnothing(e.items)
            if isnothing(to.items)
                to.items = deepcopy(e.items)
            else
                @try_catch_array merge!(to.items, e.items)
            end
        end
        merge!(+, to.lengths, e.lengths)
        to.updated += e.updated
    end
    to
end

function Base.reduce(::typeof(merge), es::Vector{ArrayEntry})
    items = [e.items for e in es if !isnothing(e.items)]
    items = if isempty(items)
        nothing
    else
        @try_catch_array reduce(merge, items)
    end
    lengths = copy(es[1].lengths)
    for i in 2:length(es), (l, c) in es[i].lengths
        lengths[l] = get(lengths, l, 0) + c
    end
    ArrayEntry(items, lengths, sum(e -> e.updated, es))
end

representative_example(e::ArrayEntry) = isnothing(e.items) ? [] : [representative_example(e.items)]

Base.hash(e::ArrayEntry, h::UInt) = hash((e.items, e.lengths, e.updated), h)
(e1::ArrayEntry == e2::ArrayEntry) = e1.updated === e2.updated &&
    e1.lengths == e2.lengths && e1.items == e2.items
