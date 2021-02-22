"""
	struct ExtractVector{T}
		item::Int
	end

represents an array of a fixed length, typically a feature vector of numbers of type T

```jloctest
julia> sc = ExtractVector(4)
julia> sc([2,3,1,4]).data
3×1 Array{Float32,2}:
 2.0
 3.0
 1.0
```
"""
struct ExtractVector{T} <: AbstractExtractor
	n::Int
end
ExtractVector(n::Int) = ExtractVector{FloatType}(n)
# todo: dodělat to, zatím je to rozdělané
# todo: check for every extractor if matrix in data and metadata is consistent, or vector, snd matrix in data does not have vector in metadata
(s::ExtractVector{T})(::MissingOrNothing; store_input=false) where {T} = ArrayNode(fill(missing, s.n, 1))
(s::ExtractVector{T})(::ExtractEmpty; store_input=false) where {T} = ArrayNode(Matrix{T}(undef, s.n, 0))
(s::ExtractVector)(v; store_input=false) = s(missing)
function (s::ExtractVector{T})(v::Vector; store_input=false) where {T}
	isempty(v) && return s(missing)
	if length(v) > s.n
		@warn "array too long, truncating"
		x = reshape(T.(v[1:s.n]), :, 1)
		return(ArrayNode(x))
	elseif length(v) < s.n
		x = Matrix{Union{Missing, T}}(missing, s.n, 1)
		x[1:length(v)] .= v
		return(ArrayNode(x))
	else
		x = reshape(T.(v), :, 1)
		return(ArrayNode(x))
	end
end

#function (s::ExtractVector{T})(v::Nothing; store_input=false) where {T}
#	x = zeros(T, s.n,1)
#	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
#end
#
#function (s::ExtractVector{T})(v; store_input=false) where {T}
#	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
#	x = zeros(T, s.n,1)
#	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
#end
#
#function (s::ExtractVector{T})(v::V; store_input=false) where {T,V<:AbstractArray}
#	isempty(v) && return s(nothing)
#	x = zeros(T, s.n, 1)
#	if length(v) > s.n
#		@warn "array too long, truncating"
#		x .= v[1:s.n]
#	elseif length(v) < s.n
#		x[1:length(v)] .= v
#	else
#		x .= v
#	end
#	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
#end

Base.length(e::ExtractVector) = e.n
Base.hash(e::ExtractVector, h::UInt) = hash(e.n, h)
Base.:(==)(e1::ExtractVector, e2::ExtractVector) = e1.n === e2.n
