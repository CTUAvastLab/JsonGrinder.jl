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
make_missing_vector(s::ExtractVector, v, store_input) =
	_make_array_node(fill(missing, s.n, 1), [v], store_input)

(s::ExtractVector{T})(v::MissingOrNothing; store_input=false) where {T} = make_missing_vector(s, v, store_input)
(s::ExtractVector{T})(::ExtractEmpty; store_input=false) where {T} = ArrayNode(Matrix{T}(undef, s.n, 0))
(s::ExtractVector)(v; store_input=false) = make_missing_vector(s, v, store_input)
function (s::ExtractVector{T})(v::Vector; store_input=false) where {T}
	isempty(v) && return make_missing_vector(s, v, store_input)
	if length(v) > s.n
		@warn "array too long, truncating"
		x = reshape(T.(v[1:s.n]), :, 1)
		return _make_array_node(x, [v], store_input)
	elseif length(v) < s.n
		x = Matrix{Union{Missing, T}}(missing, s.n, 1)
		x[1:length(v)] .= v
		return _make_array_node(x, [v], store_input)
	else
		x = reshape(T.(v), :, 1)
		return _make_array_node(x, [v], store_input)
	end
end

Base.length(e::ExtractVector) = e.n
Base.hash(e::ExtractVector, h::UInt) = hash(e.n, h)
Base.:(==)(e1::ExtractVector, e2::ExtractVector) = e1.n === e2.n
