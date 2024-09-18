"""
    CategoricalExtractor{V, I} <: Extractor

Extracts a single item interpreted as a categorical variable into a one-hot encoded vector.

There is always an extra category for an unknown value (and hence the displayed `n` is one more
than the number of categories).

# Examples
```jldoctest
julia> e = CategoricalExtractor(1:3)
CategoricalExtractor(n=4)

julia> e(2)
4×1 ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}}, Nothing}:
 ⋅
 1
 ⋅
 ⋅

julia> e(-1)
4×1 ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}}, Nothing}:
 ⋅
 ⋅
 ⋅
 1
```
"""
struct CategoricalExtractor{V} <: LeafExtractor
    category_map::Dict{V, UInt32}

    function CategoricalExtractor(categories::AbstractVector{V}) where V
        @assert !isempty(categories) "There must be at least one category!"
        @assert allunique(categories) "Categories must be unique!"
        category_map = Dict(zip(sort(categories), 1:length(categories)))
        new{V}(category_map)
    end
end

CategoricalExtractor(e::LeafEntry) = CategoricalExtractor(collect(keys(e.counts)))

function _extract(e::CategoricalExtractor{V}, v::V) where V
    v = v isa AbstractString ? shorten_string(v) : v
    get(e.category_map, v, UInt32(1 + length(e.category_map)))
end
_extract(::CategoricalExtractor, ::Missing) = _throw_missing()

_extract(e::StableExtractor{<:CategoricalExtractor}, v) = _extract(e.e, v)
_extract(::StableExtractor{<:CategoricalExtractor}, ::Missing) = missing

function _extract_leaf(e::CategoricalExtractor{V}, v::V) where V
    v = v isa AbstractString ? shorten_string(v) : v
    l = 1 + length(e.category_map)
    OneHotMatrix([get(e.category_map, v, UInt32(l))], l)
end
function _extract_leaf(e::CategoricalExtractor, ::Nothing)
    OneHotMatrix(UInt32[], 1 + length(e.category_map))
end

function _extract_leaf(e::StableExtractor{CategoricalExtractor{V}}, v::V) where V
    v = v isa AbstractString ? shorten_string(v) : v
    l = 1 + length(e.e.category_map)
    MaybeHotMatrix(Maybe{UInt32}[get(e.e.category_map, v, UInt32(l))], l)
end
function _extract_leaf(e::StableExtractor{<:CategoricalExtractor}, ::Nothing)
    MaybeHotMatrix(Maybe{UInt32}[], 1 + length(e.e.category_map))
end
function _extract_leaf(e::StableExtractor{<:CategoricalExtractor}, ::Missing)
    MaybeHotMatrix(Maybe{UInt32}[missing], 1 + length(e.e.category_map))
end

function _extract_batch(e::CategoricalExtractor, V)
    I = Vector{UInt32}(undef, length(V))
    @inbounds for (i, v) in enumerate(V)
        I[i] = _extract(e, v)
    end
    OneHotMatrix(I, 1 + length(e.category_map))
end

function _extract_batch(e::StableExtractor{<:CategoricalExtractor}, V)
    I = Vector{Maybe{UInt32}}(undef, length(V))
    @inbounds for (i, v) in enumerate(V)
        I[i] = _extract(e, v)
    end
    MaybeHotMatrix(I, 1 + length(e.e.category_map))
end

Base.hash(e::CategoricalExtractor, h::UInt) = hash((e.category_map,), h)
(e1::CategoricalExtractor == e2::CategoricalExtractor) = e1.category_map == e2.category_map
