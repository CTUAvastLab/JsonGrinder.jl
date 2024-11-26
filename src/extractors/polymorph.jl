"""
    PolymorphExtractor

Extracts to a `Mill.ProductNode` where each item is a result of different extractor.

# Examples
```jldoctest
julia> e = (NGramExtractor(), CategoricalExtractor(["tcp", "udp", "dhcp"])) |> PolymorphExtractor
PolymorphExtractor
  ├── NGramExtractor(n=3, b=256, m=2053)
  ╰── CategoricalExtractor(n=4)

julia> e("tcp")
ProductNode  1 obs
  ├── ArrayNode(2053×1 NGramMatrix with Int64 elements)  1 obs
  ╰── ArrayNode(4×1 OneHotArray with Bool elements)  1 obs

julia> e("http")
ProductNode  1 obs
  ├── ArrayNode(2053×1 NGramMatrix with Int64 elements)  1 obs
  ╰── ArrayNode(4×1 OneHotArray with Bool elements)  1 obs
```
"""
struct PolymorphExtractor{T <: Union{NamedTuple, Tuple}} <: Extractor
    extractors::T
end

PolymorphExtractor(extractors::Extractor...) = PolymorphExtractor(extractors)
PolymorphExtractor(; extractors...) = PolymorphExtractor(NamedTuple(extractors))

MacroTools.@forward PolymorphExtractor.extractors Base.getindex, Base.get, Base.haskey,
    Base.keys, Base.length, Base.isempty

function (e::PolymorphExtractor)(v::Maybe; store_input=Val(false))
    ProductNode(map(e -> e(v; store_input), e.extractors), _metadata(v, store_input))
end
(e::PolymorphExtractor)(::ExtractEmpty) = ProductNode(map(e -> e(extractempty), e.extractors))

(e::PolymorphExtractor)(::Nothing; store_input=Val(false)) = _error_null_values()

function extract(e::PolymorphExtractor, V; store_input=Val(false))
    ProductNode(map(e -> extract(e, V; store_input), e.extractors), _metadata_batch(V, store_input))
end

Base.hash(e::PolymorphExtractor, h::UInt) = hash(e.extractors, h)
(e1::PolymorphExtractor == e2::PolymorphExtractor) = e1.extractors == e2.extractors
