"""
	struct ExtractVector{T}
		item::T
	end

	represents an array of a fixed length, typically a feature vector

```juliadoctest
julia> sc = ExtractVector(Float32)
julia> sc([2,3,1,4]).data
3×4 Array{Float32,2}:
 1.0  0.0  0.0  0.0
 0.0  1.0  0.0  0.0
 0.0  0.0  0.0  1.0

```

```juliadoctest
julia> sc = ExtractVector(ExtractScalar())
julia> sc([2,3,4]).data
 2.0  3.0  4.0
```
"""
struct ExtractVector{T} <: AbstractExtractor
	n::Int
end
ExtractVector(n::Int) = ExtractVector{Float32}(n)

extractsmatrix(s::ExtractVector) = false

(s::ExtractVector{T})(v::V) where {T, V<:Nothing} = ArrayNode(zeros(T, s.n,1))
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

function Base.show(io::IO, m::ExtractVector; pad = [], key::String="")
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "
	paddedprint(io,"$(key)FeatureVector with $(m.n) items\n", color = c, pad = pad)
end
