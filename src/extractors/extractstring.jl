using Mill: NGramMatrix

"""
	struct ExtractString{T} <: AbstractExtractor
		n::Int
		b::Int
		m::Int
	end

Represents `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

# Example
```jldoctest
julia> ExtractString()("hello")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{String,Int64},Nothing}:
 "hello"

julia> ExtractString()(missing)
2053×1 Mill.ArrayNode{Mill.NGramMatrix{Missing,Missing},Nothing}:
 missing

julia> ExtractString()(["hello", "world"])
2053×2 Mill.ArrayNode{Mill.NGramMatrix{String,Int64},Nothing}:
 "hello"
 "world"
```
"""
struct ExtractString <: AbstractExtractor
	n::Int
	b::Int
	m::Int
end


ExtractString() = ExtractString(3, 256, 2053)
make_missing_string(s::ExtractString, v, store_input) =
	_make_array_node(NGramMatrix(missing, s.n, s.b, s.m), [v], store_input)
(s::ExtractString)(v::String; store_input=false) = _make_array_node(NGramMatrix([v], s.n, s.b, s.m), [v], store_input)
(s::ExtractString)(v::Vector{String}; store_input=false) =
	_make_array_node(NGramMatrix(v, s.n, s.b, s.m), v, store_input)
(s::ExtractString)(v::AbstractString; store_input=false) = s(String(v); store_input)
(s::ExtractString)(v::MissingOrNothing; store_input=false) = make_missing_string(s, v, store_input)
(s::ExtractString)(v::ExtractEmpty; store_input=false) = ArrayNode(NGramMatrix(Vector{String}(), s.n, s.b, s.m))
(s::ExtractString)(v; store_input=false) = make_missing_string(s, v, store_input)
(s::ExtractString)(v::Symbol; store_input=false) = s(String(v); store_input)

# todo: add jldoctest here so it's better
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
julia> JsonGrinder.extractscalar(String, 3, 256, 2053)("5")
2053×1 Mill.ArrayNode{Mill.NGramMatrix{String,Int64},Nothing}:
 "5"

julia> JsonGrinder.extractscalar(Int32, 3, 256)("5")
1×1 Mill.ArrayNode{Array{Int32,2},Nothing}:
 512
```
"""
extractscalar(::Type{T}, n = 3, b = 256, m = 2053) where {T<:AbstractString} = ExtractString(n, b, m)

Base.hash(e::ExtractString, h::UInt) = hash((e.n, e.b, e.m), h)
Base.:(==)(e1::ExtractString, e2::ExtractString) = e1.n === e2.n && e1.b === e2.b && e1.m === e2.m

# to be compatible with the number version
extractscalar(::Type{T}, e::Entry) where {T<:AbstractString} = ExtractString()
