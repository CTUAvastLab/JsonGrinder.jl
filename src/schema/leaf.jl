"""
    LeafEntry{T} <: AbstractJSONEntry

Keeps statistics about scalar values of type `T` in leaves:
- how many times specific values appeared (at most [`JsonGrinder.max_keys()`](@ref) is held)
- how many times the entry was updated
"""
mutable struct LeafEntry{T} <: AbstractJSONEntry
    const counts::Dict{T, Int}
    updated::Int
end

LeafEntry(::Type{<:Number}) = LeafEntry(Dict{Number, Int}(), 0)
LeafEntry(::Type{<:AbstractString}) = LeafEntry(Dict{String, Int}(), 0)

function shorten_string(v::AbstractString)
    if length(v) ≤ max_string_length()
        v
    else
        join((v[1:max_string_length()], length(v), bytes2hex(sha1(v))), "_")
    end
end

update!(e::LeafEntry{Number}, v::Number) = _update_leaf!(e, v)
update!(e::LeafEntry{String}, v::AbstractString) = _update_leaf!(e, shorten_string(v))

function _update_leaf!(e::LeafEntry, v)
    if length(e.counts) < max_keys()
        e.counts[v] = get(e.counts, v, 0) + 1
    elseif haskey(e.counts, v)
        e.counts[v] += 1
    end
    e.updated += 1
end

function Base.merge!(to::LeafEntry{T}, es::LeafEntry{T}...) where T
    for e in es
        for (v, c) in e.counts
            if length(to.counts) < max_keys()
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
            elseif length(counts) < max_keys()
                counts[k] = c
            end
        end
    end
    LeafEntry(counts, sum(e -> e.updated, es))
end

function Base.show(io::IO, m::MIME"text/plain", @nospecialize(e::LeafEntry))
    print(io, "LeafEntry storing ")
    _show_types(io, e)
    if isempty(e.counts)
        print(io, ".")
    else
        s = sprint((io, x) -> show(io, m, x), e.counts; context=io)
        print(io, ":\n", split(s, '\n'; limit=2)[2])
    end
end

function _show_details(io, e::LeafEntry)
    print(io, " (")
    _show_types(io, e)
    print(io, ")")
end

function _show_types(io, e::LeafEntry)
    print(io, length(e.counts), " unique `", keytype(e.counts), "` values")
end

Base.hash(e::LeafEntry, h::UInt) = hash((e.counts, e.updated), h)
(e1::LeafEntry == e2::LeafEntry) = e1.updated == e2.updated && e1.counts == e2.counts
