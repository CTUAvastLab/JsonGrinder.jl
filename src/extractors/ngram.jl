"""
    NGramExtractor{T} <: Extractor

Represents `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

The `extract_missing` field determines whether extractor may or may not accept `missing`.
If `extract_missing` is false, it does not accept missing values. If `extract_missing` is true, it accepts missing values,
and always returns Mill structure of type Union{Missing, T} due to type stability reasons.

# Example
```jldoctest
julia> using Mill: catobs

julia> NGramExtractor(true)("hello")
2053×1 ArrayNode{NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "hello"

julia> mapreduce(NGramExtractor(true), catobs, (["hello", "world"]))
2053×2 ArrayNode{NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "hello"
 "world"
 
julia> mapreduce(NGramExtractor(true), catobs, ["hello", missing])
2053×2 ArrayNode{NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "hello"
 missing

julia> NGramExtractor(true)(missing)
2053×1 ArrayNode{NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 missing

julia> NGramExtractor(false)("hello")
2053×1 ArrayNode{NGramMatrix{String, Vector{String}, Int64}, Nothing}:
 "hello"

julia> mapreduce(NGramExtractor(false), catobs, (["hello", "world"]))
2053×2 ArrayNode{NGramMatrix{String, Vector{String}, Int64}, Nothing}:
 "hello"
 "world"

julia> NGramExtractor(false)(["hello", "world"])
ERROR: This extractor does not support missing values

```
	extractscalar(Type{String}, n = 3, b = 256, m = 2053)

represents strings as ngrams with
- `n` (the degree of ngram),
- `b` base of string,
- `m` modulo on index of the token to reduce dimension

	extractscalar(Type{Number}, m = 0, s = 1)

extracts number subtracting `m` and multiplying by `s`

# Example
```jldoctest
julia> JsonGrinder.extractscalar(String, 3, 256, 2053, true)("5")
2053×1 ArrayNode{NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "5"

julia> JsonGrinder.extractscalar(Int32, 3, 256, true)("5")
1×1 ArrayNode{Matrix{Union{Missing, Int32}}, Nothing}:
 512

julia> JsonGrinder.extractscalar(String, 3, 256, 2053, false)("5")
2053×1 ArrayNode{NGramMatrix{String, Vector{String}, Int64}, Nothing}:
 "5"

julia> JsonGrinder.extractscalar(Int32, 3, 256, false)("5")
1×1 ArrayNode{Matrix{Int32}, Nothing}:
 512
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
