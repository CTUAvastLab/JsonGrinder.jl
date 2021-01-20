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

(s::ExtractVector{T})(::V) where {T,V<:Union{Missing, Nothing}} = ArrayNode(fill(missing, s.n, 1))
(s::ExtractVector{T})(::ExtractEmpty) where {T}= ArrayNode(Matrix{T}(undef, s.n, 0))
(s::ExtractVector)(v) = s(missing)
function (s::ExtractVector{T})(v::V) where {T,V<:Vector}
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

Base.length(e::ExtractVector) = e.n
Base.hash(e::ExtractVector, h::UInt) = hash(e.n, h)
Base.:(==)(e1::ExtractVector, e2::ExtractVector) = e1.n === e2.n
