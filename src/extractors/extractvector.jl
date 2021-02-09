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
	uniontypes::Bool
end
ExtractVector(n::Int, uniontypes = true) = ExtractVector{FloatType}(n, uniontypes)

(s::ExtractVector{T})(::V) where {T,V<:Union{Missing, Nothing}} =
	s.uniontypes ? ArrayNode(Matrix{Union{Missing, T}}(fill(missing, s.n, 1))) : error("This extractor does not support missing values")
(s::ExtractVector{T})(::ExtractEmpty) where {T} =
	ArrayNode(s.uniontypes ? Matrix{Union{Missing, T}}(undef, s.n, 0) : Matrix{T}(undef, s.n, 0))
(s::ExtractVector)(v) = s(missing)

function (s::ExtractVector{T})(v::V) where {T,V<:Vector}
	isempty(v) && s.uniontypes && return s(missing)
	isempty(v) && !s.uniontypes && error("This extractor does not support missing values")
	if length(v) > s.n
		@warn "array too long, truncating"
		x = reshape(T.(v[1:s.n]), :, 1)
	elseif length(v) < s.n
		!s.uniontypes && error("This extractor does not support missing values")
		x = Matrix{Union{Missing, T}}(missing, s.n, 1)
		x[1:length(v)] .= v
	else
		x = reshape(T.(v), :, 1)
	end
	return ArrayNode(s.uniontypes ? Matrix{Union{Missing, T}}(x) : x)
end

Base.length(e::ExtractVector) = e.n
Base.hash(e::ExtractVector, h::UInt) = hash((e.n, e.uniontypes), h)
Base.:(==)(e1::ExtractVector, e2::ExtractVector) = e1.n === e2.n && e1.uniontypes === e2.uniontypes
