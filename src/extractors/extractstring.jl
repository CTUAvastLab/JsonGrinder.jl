using Mill: NGramMatrix

"""
	struct ExtractString{T} <: AbstractExtractor
		n::Int
		b::Int
		m::Int
		uniontypes::Bool
	end

Represents `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

The `uniontypes` field determines whether extractor may or may not accept `missing`.
If `uniontypes` is false, it does not accept missing values. If `uniontypes` is true, it accepts missing values,
and always returns Mill structure of type Union{Missing, T} due to type stability reasons.

# Example
```jldoctest
julia> ExtractString(true)("hello")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "hello"

julia> ExtractString(true)(["hello", "world"])
2053×2 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "hello"
 "world"

julia> ExtractString(true)(["hello", missing])
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 missing

julia> ExtractString(true)(missing)
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 missing

julia> ExtractString(false)("hello")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{String, Vector{String}, Int64}, Nothing}:
 "hello"

julia> ExtractString(false)(["hello", "world"])
2053×2 Mill.ArrayNode{Mill.NGramMatrix{String, Vector{String}, Int64}, Nothing}:
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
make_missing_string(s::ExtractString, v, store_input) =
	s.uniontypes ?
	_make_array_node(NGramMatrix(MaybeString[missing], s.n, s.b, s.m), [v], store_input) :
	error("This extractor does not support missing values")
stabilize_types_string(s::ExtractString, x) = s.uniontypes ? Vector{MaybeString}(x) : x
make_empty_string(s::ExtractString, store_input) where {T} =
	ArrayNode(NGramMatrix(s.uniontypes ? Vector{MaybeString}() : Vector{String}(), s.n, s.b, s.m))

(s::ExtractString)(v::String; store_input=false) =
	_make_array_node(NGramMatrix(stabilize_types_string(s, [v]), s.n, s.b, s.m), [v], store_input)
(s::ExtractString)(v::AbstractString; store_input=false) = s(String(v); store_input)
(s::ExtractString)(v::MissingOrNothing; store_input=false) = make_missing_string(s, v, store_input)
(s::ExtractString)(v::ExtractEmpty; store_input=false) = make_empty_string(s, store_input)
(s::ExtractString)(v; store_input=false) = make_missing_string(s, v, store_input)
(s::ExtractString)(v::Symbol; store_input=false) = s(String(v); store_input)

"""
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
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Union{Missing, String}, Vector{Union{Missing, String}}, Union{Missing, Int64}}, Nothing}:
 "5"

julia> JsonGrinder.extractscalar(Int32, 3, 256, true)("5")
1×1 Mill.ArrayNode{Matrix{Union{Missing, Int32}}, Nothing}:
 512

julia> JsonGrinder.extractscalar(String, 3, 256, 2053, false)("5")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{String, Vector{String}, Int64}, Nothing}:
 "5"

julia> JsonGrinder.extractscalar(Int32, 3, 256, false)("5")
1×1 Mill.ArrayNode{Matrix{Int32}, Nothing}:
 512
```
"""
extractscalar(::Type{<:AbstractString}, n = 3, b = 256, m = 2053, uniontypes = true) = ExtractString(n, b, m, uniontypes)

Base.hash(e::ExtractString, h::UInt) = hash((e.n, e.b, e.m, e.uniontypes), h)
Base.:(==)(e1::ExtractString, e2::ExtractString) =
	e1.n === e2.n && e1.b === e2.b && e1.m === e2.m && e1.uniontypes === e2.uniontypes

# to be compatible with the number version
extractscalar(::Type{<:AbstractString}, e::Entry, uniontypes::Bool = true) = ExtractString(uniontypes)
