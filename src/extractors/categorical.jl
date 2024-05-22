"""
    CategoricalExtractor{V, I} <: Extractor

Converts a single item to a one-hot encoded vector and an array of items into a one-hot matrix.

There is always alocated an extra element for a unknown value.

If passed `missing`, if `extract_missing` is true, returns column of missing values, otherwise raises error.

If `extract_missing` is true, it allows extracting `missing` values and all extracted values will be of type
`Union{Missing, <other type>}` due to type stability reasons. Otherwise missings extraction is not allowed.

# Examples

```jldoctest
julia> using Mill: catobs

julia> e = CategoricalExtractor(2:4, true);

julia> mapreduce(e, catobs, [2,3,1,4])
4×4 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
  true    ⋅      ⋅      ⋅
   ⋅     true    ⋅      ⋅
   ⋅      ⋅      ⋅     true
   ⋅      ⋅     true    ⋅

julia> mapreduce(e, catobs, [1,missing,5])
4×3 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
   ⋅    missing    ⋅
   ⋅    missing    ⋅
   ⋅    missing    ⋅
  true  missing   true

julia> e(4)
4×1 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
   ⋅
   ⋅
  true
   ⋅

julia> e(missing)
4×1 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
 missing
 missing
 missing
 missing

julia> e = CategoricalExtractor(2:4, false);

julia> mapreduce(e, catobs, [2, 3, 1, 4])
4×4 ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}}, Nothing}:
 1  ⋅  ⋅  ⋅
 ⋅  1  ⋅  ⋅
 ⋅  ⋅  ⋅  1
 ⋅  ⋅  1  ⋅

julia> e(4)
 4×1 ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}}, Nothing}:
 ⋅
 ⋅
 1
 ⋅
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

function extract_leaf(e::CategoricalExtractor{V}, v::V) where V
    v = v isa AbstractString ? shorten_string(v) : v
    l = 1 + length(e.category_map)
    OneHotMatrix([get(e.category_map, v, UInt32(l))], l)
end
function extract_leaf(e::CategoricalExtractor, ::Nothing)
    OneHotMatrix(UInt32[], 1 + length(e.category_map))
end

function extract_leaf(e::StableExtractor{CategoricalExtractor{V}}, v::V) where V
    v = v isa AbstractString ? shorten_string(v) : v
    l = 1 + length(e.e.category_map)
    MaybeHotMatrix(Maybe{UInt32}[get(e.e.category_map, v, UInt32(l))], l)
end
function extract_leaf(e::StableExtractor{<:CategoricalExtractor}, ::Nothing)
    MaybeHotMatrix(Maybe{UInt32}[], 1 + length(e.e.category_map))
end
function extract_leaf(e::StableExtractor{<:CategoricalExtractor}, ::Missing)
    MaybeHotMatrix(Maybe{UInt32}[missing], 1 + length(e.e.category_map))
end

Base.hash(e::CategoricalExtractor, h::UInt) = hash((e.category_map,), h)
(e1::CategoricalExtractor == e2::CategoricalExtractor) = e1.category_map == e2.category_map
