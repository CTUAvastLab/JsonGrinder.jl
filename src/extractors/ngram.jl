"""
    NGramExtractor{T} <: Extractor

Extracts `String` as `n-`grams (`Mill.NGramMatrix`).

# Examples
```jldoctest
julia> e = NGramExtractor()
NGramExtractor(n=3, b=256, m=2053)

julia> e("foo")
2053×1 ArrayNode{NGramMatrix{String, Vector{String}, Int64}, Nothing}:
 "foo"

```
"""
struct NGramExtractor <: LeafExtractor
    n::Int
    b::Int
    m::Int
end

NGramExtractor(; n::Int=3, b::Int=256, m::Int=2053) = NGramExtractor(n, b, m)

function extract_leaf(e::NGramExtractor, v::AbstractString)
    NGramMatrix(String[string(v)], e.n, e.b, e.m)
end
function extract_leaf(e::NGramExtractor, ::Nothing)
    NGramMatrix(String[], e.n, e.b, e.m)
end
function extract_leaf(e::StableExtractor{NGramExtractor}, v::AbstractString)
    NGramMatrix(Maybe{String}[string(v)], e.e.n, e.e.b, e.e.m)
end
function extract_leaf(e::StableExtractor{NGramExtractor}, ::Nothing)
    NGramMatrix(Maybe{String}[], e.e.n, e.e.b, e.e.m)
end
function extract_leaf(e::StableExtractor{NGramExtractor}, ::Missing)
    NGramMatrix(Maybe{String}[missing], e.e.n, e.e.b, e.e.m)
end

Base.hash(e::NGramExtractor, h::UInt) = hash((e.n, e.b, e.m), h)
(e1::NGramExtractor == e2::NGramExtractor) = e1.n == e2.n && e1.b == e2.b && e1.m == e2.m
