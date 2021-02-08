"""
	struct ExtractString{T} <: AbstractExtractor
		n::Int
		b::Int
		m::Int
		full::Bool
	end

Represents `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

The `full` field determines whether extractor may or may not accept `missing`. If `full` is true, it does not accept
missing values. If `full` is false, it accepts missing values, and always returns Mill structure of type
Union{Missing, T} due to type stability reasons.

"""
struct ExtractString <: AbstractExtractor
	n::Int
	b::Int
	m::Int
	full::Bool
end


ExtractString() = ExtractString(3, 256, 2053, true)
(s::ExtractString)(v::String) = ArrayNode(Mill.NGramMatrix([v], s.n, s.b, s.m))
(s::ExtractString)(v::Vector{String}) = ArrayNode(Mill.NGramMatrix(v, s.n, s.b, s.m))
(s::ExtractString)(v::AbstractString) = s(String(v))
(s::ExtractString)(v::Union{Missing, Nothing}) = ArrayNode(Mill.NGramMatrix(missing, s.n, s.b, s.m))
(s::ExtractString)(v::ExtractEmpty) = ArrayNode(Mill.NGramMatrix(Vector{String}(), s.n, s.b, s.m))
(s::ExtractString)(v) = s(missing)
(s::ExtractString)(v::Symbol) = s(String(v))
# todo: add jldoctest here so it's better
"""
	extractscalar(Type{String}, n = 3, b = 256, m = 2053)

represents strings as ngrams with
- `n` (the degree of ngram),
- `b` base of string,
- `m` modulo on index of the token to reduce dimension

	extractscalar(Type{Number}, m = 0, s = 1)

extracts number subtracting `m` and multiplying by `s`
"""
extractscalar(::Type{T}, n = 3, b = 256, m = 2053, full = true) where {T<:AbstractString} = ExtractString(n, b, m, full)

Base.hash(e::ExtractString, h::UInt) = hash((e.n, e.b, e.m, e.full), h)
Base.:(==)(e1::ExtractString, e2::ExtractString) = e1.n === e2.n && e1.b === e2.b && e1.m === e2.m && e1.full === e2.full

# to be compatible with the number version
extractscalar(::Type{T}, e::Entry) where {T<:AbstractString} = ExtractString()
