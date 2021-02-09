using Mill: NGramMatrix

"""
	struct ExtractString{T} <: AbstractExtractor
		n::Int
		b::Int
		m::Int
		full::Bool
	end

Represents `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

The `uniontypes` field determines whether extractor may or may not accept `missing`.
If `uniontypes` is false, it does not accept missing values. If `uniontypes` is true, it accepts missing values,
and always returns Mill structure of type Union{Missing, T} due to type stability reasons.

```jldoctest
julia> ExtractString(true)("hello")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String},Union{Missing, Int64}},Nothing}:
 "hello"

julia> ExtractString(true)(["hello", "world"])
2053×2 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String},Union{Missing, Int64}},Nothing}:
 "hello"
 "world"

julia> ExtractString(true)(["hello", missing])
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String},Union{Missing, Int64}},Nothing}:
 missing

julia> ExtractString(true)(missing)
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String},Union{Missing, Int64}},Nothing}:
 missing

julia> ExtractString(false)("hello")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{String,Int64},Nothing}:
 "hello"

julia> ExtractString(false)(["hello", "world"])
2053×2 Mill.ArrayNode{Mill.NGramMatrix{String,Int64},Nothing}:
 "hello"
 "world"
```
"""
struct ExtractString <: AbstractExtractor
	n::Int
	b::Int
	m::Int
	uniontypes::Bool
end

const MaybeString = Union{Missing, String}

ExtractString(n::Int, b::Int, m::Int) = ExtractString(n, b, m, true)
ExtractString(uniontypes::Bool) = ExtractString(3, 256, 2053, uniontypes)
ExtractString() = ExtractString(3, 256, 2053, true)
(s::ExtractString)(v::String) = ArrayNode(NGramMatrix(s.uniontypes ? MaybeString[v] : [v], s.n, s.b, s.m))
(s::ExtractString)(v::Vector{String}) = ArrayNode(NGramMatrix(s.uniontypes ? Vector{MaybeString}(v) : v, s.n, s.b, s.m))
(s::ExtractString)(v::AbstractString) = s(String(v))
(s::ExtractString)(v::MissingOrNothing) =
	s.uniontypes ? ArrayNode(NGramMatrix(MaybeString[missing], s.n, s.b, s.m)) : error("This extractor does not support missing values")
(s::ExtractString)(v::ExtractEmpty) =
	ArrayNode(NGramMatrix(s.uniontypes ? Vector{MaybeString}() : Vector{String}(), s.n, s.b, s.m))
(s::ExtractString)(v) = s(missing)
(s::ExtractString)(v::Symbol) = s(String(v))

"""
	extractscalar(Type{String}, n = 3, b = 256, m = 2053)

represents strings as ngrams with
- `n` (the degree of ngram),
- `b` base of string,
- `m` modulo on index of the token to reduce dimension

	extractscalar(Type{Number}, m = 0, s = 1)

extracts number subtracting `m` and multiplying by `s`
"""
extractscalar(::Type{<:AbstractString}, n = 3, b = 256, m = 2053, uniontypes = true) = ExtractString(n, b, m, uniontypes)

Base.hash(e::ExtractString, h::UInt) = hash((e.n, e.b, e.m, e.uniontypes), h)
Base.:(==)(e1::ExtractString, e2::ExtractString) =
	e1.n === e2.n && e1.b === e2.b && e1.m === e2.m && e1.uniontypes === e2.uniontypes

# to be compatible with the number version
extractscalar(::Type{<:AbstractString}, e::Entry, uniontypes::Bool = true) = ExtractString(uniontypes)
