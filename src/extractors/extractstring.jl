struct ExtractString{T} <: AbstractExtractor
	datatype::Type{T}
	n::Int
	b::Int
	m::Int
end

ExtractString(::Type{T}) where {T<:String} = ExtractString(T, 3, 256, 2053)
(s::ExtractString)(v)   = ArrayNode(Mill.NGramMatrix([v], s.n, s.b, s.m))
(s::ExtractString)(v::S) where {S<:Nothing}= ArrayNode(Mill.NGramMatrix([""], s.n, s.b, s.m))
extractsmatrix(s::ExtractString) = false
dimension(s::ExtractString) = s.m
function Base.show(io::IO, m::ExtractString;pad = [], key::String="") 
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "; 
	paddedprint(io,"$(key)$(m.datatype)\n", color = c, pad = pad)
end


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
