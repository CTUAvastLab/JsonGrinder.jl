struct ExtractString{T} <: AbstractExtractor
	datatype::Type{T}
	n::Int
	b::Int
	m::Int
end

ExtractString(::Type{T}) where {T<:String} = ExtractString(T, 3, 256, 2053)
function (s::ExtractString)(v::String; store_input=false)
	x = Mill.NGramMatrix([v], s.n, s.b, s.m)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
 end
(s::ExtractString)(v::AbstractString; store_input=false) = s(String(v); store_input)
function (s::ExtractString)(v::S; store_input=false) where {S<:Nothing}
	x = Mill.NGramMatrix([""], s.n, s.b, s.m)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
 end
function (s::ExtractString)(v; store_input=false)
	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
 	x = Mill.NGramMatrix([""], s.n, s.b, s.m)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end

extractsmatrix(s::ExtractString) = false

"""
	extractscalar(Type{String}, n = 3, b = 256, m = 2053)

	represents strings as ngrams with
		--- `n` (the degree of ngram),
		--- `b` base of string,
		--- `m` modulo on index of the token to reduce dimension

	extractscalar(Type{Number}, m = 0, s = 1)
	extracts number subtracting `m` and multiplying by `s`
"""
extractscalar(::Type{T}, n = 3, b = 256, m = 2053) where {T<:AbstractString} = ExtractString(T, n, b, m)
extractscalar(::Type{T}, m = zero(T), s = one(T)) where {T<:Number} = ExtractScalar(T, m, s)

Base.hash(e::ExtractString, h::UInt) = hash((e.datatype, e.n, e.b, e.m), h)
Base.:(==)(e1::ExtractString, e2::ExtractString) = e1.datatype == e2.datatype && e1.n === e2.n && e1.b === e2.b && e1.m === e2.m

# to be compatible with the number version
extractscalar(::Type{T}, e::Entry) where {T<:AbstractString} = extractscalar(T)
