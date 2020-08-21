"""
	struct ExtractVector{T}
		item::Int
	end

	represents an array of a fixed length, typically a feature vector

```juliadoctest
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

extractsmatrix(s::ExtractVector) = false

(s::ExtractVector{T})(::Nothing) where {T} = ArrayNode(zeros(T, s.n,1))
(s::ExtractVector)(v) = s(nothing)
function (s::ExtractVector{T})(v::V) where {T,V<:AbstractArray}
	isempty(v) && return s(nothing)
	x = zeros(T, s.n, 1)
	if length(v) > s.n
		@warn "array too long, truncating"
		x .= v[1:s.n]
	elseif length(v) < s.n
		x[1:length(v)] .= v
	else
		x .= v
	end
	ArrayNode(x)
end

Base.length(e::ExtractVector) = e.n
Base.hash(e::ExtractVector, h::UInt) = hash(e.n, h)
Base.:(==)(e1::ExtractVector, e2::ExtractVector) = e1.n === e2.n
