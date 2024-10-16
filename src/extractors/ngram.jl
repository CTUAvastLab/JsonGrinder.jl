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

function _extract_leaf(e::NGramExtractor, v::AbstractString)
    NGramMatrix(String[string(v)], e.n, e.b, e.m)
end
function _extract_leaf(e::NGramExtractor, ::ExtractEmpty)
    NGramMatrix(String[], e.n, e.b, e.m)
end
function _extract_leaf(e::StableExtractor{NGramExtractor}, v::AbstractString)
    NGramMatrix(Maybe{String}[string(v)], e.e.n, e.e.b, e.e.m)
end
function _extract_leaf(e::StableExtractor{NGramExtractor}, ::ExtractEmpty)
    NGramMatrix(Maybe{String}[], e.e.n, e.e.b, e.e.m)
end
function _extract_leaf(e::StableExtractor{NGramExtractor}, ::Missing)
    NGramMatrix(Maybe{String}[missing], e.e.n, e.e.b, e.e.m)
end

_extract_value(::NGramExtractor, v::AbstractString) = string(v)
_extract_value(::NGramExtractor, ::Missing) = _error_missing()
_extract_value(::NGramExtractor, ::Nothing) = _error_null_values()

function _extract_batch(e::NGramExtractor, V)
    S = Vector{String}(undef, length(V))
    @inbounds for (i, v) in enumerate(V)
        S[i] = _extract_value(e, v)
    end
    NGramMatrix(S, e.n, e.b, e.m)
end

_extract_value(e::StableExtractor{NGramExtractor}, v::AbstractString) = _extract_value(e.e, v)
_extract_value(::StableExtractor{NGramExtractor}, ::Missing) = missing
_extract_value(::StableExtractor{NGramExtractor}, ::Nothing) = _error_null_values()

function _extract_batch(e::StableExtractor{NGramExtractor}, V)
    S = Vector{Maybe{String}}(undef, length(V))
    @inbounds for (i, v) in enumerate(V)
        S[i] = _extract_value(e, v)
    end
    NGramMatrix(S, e.e.n, e.e.b, e.e.m)
end

Base.hash(e::NGramExtractor, h::UInt) = hash((e.n, e.b, e.m), h)
(e1::NGramExtractor == e2::NGramExtractor) = e1.n == e2.n && e1.b == e2.b && e1.m == e2.m
