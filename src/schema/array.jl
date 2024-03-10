"""
    ArrayEntry <: AbstractJSONEntry

Keeps statistics about an "array" entry in JSONs.
- statistics of all individual values
- how many times the entry was updated
"""
mutable struct ArrayEntry <: AbstractJSONEntry
    items::Union{Nothing, AbstractJSONEntry}
    const lengths::Dict{Int, Int}
    updated::Int
end

ArrayEntry() = ArrayEntry(nothing, Dict{Int,Int}(), 0)

macro try_catch_array_entry(ex)
    quote
        try
            $(esc(ex))
        catch e
            if e isa InconsistentSchema
                push!(e.path, "[]")
            end
            rethrow(e)
        end
    end
end


function update!(e::ArrayEntry, v::AbstractVector)
    n = length(v)
    e.lengths[n] = get(e.lengths, n, 0) + 1
    if isnothing(e.items) && n > 0
        e.items = _newentry(v[1])
    end
    for x in v
        @try_catch_array_entry update!(e.items, x)
    end
    e.updated += 1
end

function Base.merge!(to::ArrayEntry, es::ArrayEntry...)
    for e in es
        if !isnothing(e.items)
            if isnothing(to.items)
                to.items = deepcopy(e.items)
            else
                @try_catch_array_entry merge!(to.items, e.items)
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
        @try_catch_array_entry reduce(merge, items)
    end
    lengths = copy(es[1].lengths)
    for i in 2:length(es), (l, c) in es[i].lengths
        lengths[l] = get(lengths, l, 0) + c
    end
    ArrayEntry(items, lengths, sum(e -> e.updated, es))
end

Base.hash(e::ArrayEntry, h::UInt) = hash((e.items, e.lengths, e.updated), h)
(e1::ArrayEntry == e2::ArrayEntry) = e1.updated === e2.updated &&
    e1.lengths == e2.lengths && e1.items == e2.items
