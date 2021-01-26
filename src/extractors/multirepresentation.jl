"""
	MultipleRepresentation(extractors::Tuple)

Extractor extracts item to a `ProductNode` where each item is different extractor and item is
extracted by all extractors in multirepresentation.

# Examples

## Example of both categorical and string representation

One of usecases is to use string representation for strings and categorical variable representation for most frequent values.
This allows model to more easily learn frequent or somehow else significant values, which creating meaningful representation
for previously unseen inputs.

```jldoctest
julia> e = MultipleRepresentation((ExtractString(), ExtractCategorical(["tcp", "udp", "dhcp"])));

julia> s1 = e("tcp")
Mill.ProductNode with 1 obs
  ├── e1: ArrayNode(2053×1 NGramMatrix, Int64) with 1 obs
  └── e2: ArrayNode(4×1 MaybeHotMatrix, Bool) with 1 obs

julia> s1[:e1]
Mill.ArrayNode{Mill.NGramMatrix{String,Array{String,1},Int64},Nothing}:
 "tcp"

julia> s1[:e2]
Mill.ArrayNode{Mill.MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool},Nothing}:
 false
  true
 false
 false

julia> s2 = e("http")
Mill.ProductNode with 1 obs
  ├── e1: Mill.ArrayNode(2053×1 NGramMatrix, Int64) with 1 obs
  └── e2: Mill.ArrayNode(4×1 MaybeHotMatrix, Bool) with 1 obs

julia> s2[:e1]
ArrayNode{NGramMatrix{String,Array{String,1},Int64},Nothing}:
 "http"

julia> s2[:e2]
ArrayNode{MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool},Nothing}:
 false
 false
 false
  true
```

## Example of irregular schema representation

The other usecase is to handle irregular schema, where extractor returns `missing` representation if it's unable to
extract it properly. Of course there do not have to be only leaf value extractors, some extractors may be ExtractDict,
while other are extracting leaves etc.

```jldoctest
julia> e = MultipleRepresentation((ExtractString(), ExtractScalar(Float32, 2, 3)));

julia> s1 = e(5)
Mill.ProductNode with 1 obs
  ├── e1: Mill.ArrayNode(2053×1 NGramMatrix, Missing) with 1 obs
  └── e2: Mill.ArrayNode(1×1 Array, Float32) with 1 obs

julia> s1[:e1]
Mill.ArrayNode{Mill.NGramMatrix{Missing,Array{Missing,1},Missing},Nothing}:
 missing

julia> s1[:e2]
Mill.ArrayNode{Array{Float32,2},Nothing}:
 9.0f0

julia> s2 = e("hi")
Mill.ProductNode with 1 obs
  ├── e1: Mill.ArrayNode(2053×1 NGramMatrix, Int64) with 1 obs
  └── e2: Mill.ArrayNode(1×1 Array, Missing) with 1 obs

julia> s2[:e1]
Mill.ArrayNode{Mill.NGramMatrix{String,Array{String,1},Int64},Nothing}:
 "hi"

julia> s2[:e2]
Mill.ArrayNode{Array{Missing,2},Nothing}:
 missing

```
"""
struct MultipleRepresentation{E<:Union{NamedTuple, Tuple}}
	extractors::E
end
# todo: add jldoctest example
MultipleRepresentation(vs::Vector) = MultipleRepresentation((;[Symbol("e$(i)") => v for (i,v) in enumerate(vs)]...))
MultipleRepresentation(vs::Tuple) = MultipleRepresentation((;[Symbol("e$(i)") => v for (i,v) in enumerate(vs)]...))
(m::MultipleRepresentation)(x) = ProductNode(map(e -> e(x), m.extractors))
Base.keys(e::MultipleRepresentation) = keys(e.extractors)

Base.hash(e::MultipleRepresentation, h::UInt) = hash(e.extractors, h)
Base.:(==)(e1::MultipleRepresentation, e2::MultipleRepresentation) = e1.extractors == e2.extractors
Base.getindex(e::MultipleRepresentation, i::Int) = e.extractors[i]
