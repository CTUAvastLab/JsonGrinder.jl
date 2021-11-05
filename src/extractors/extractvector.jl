"""
    struct ExtractVector{T} <: AbstractExtractor
	    n::Int
	    uniontypes::Bool
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

make_missing_vector(s::ExtractVector, v, store_input) =
    s.uniontypes ?
    _make_array_node(stabilize_types_vector(s, fill(missing, s.n, 1)), [v], store_input) :
    error("This extractor does not support missing values")
stabilize_types_vector(s::ExtractVector{T}, x) where {T} = s.uniontypes ? Matrix{Union{Missing, T}}(x) : x

(s::ExtractVector)(v::MissingOrNothing; store_input=false) = make_missing_vector(s, v, store_input)
(s::ExtractVector{T})(::ExtractEmpty; store_input=false) where {T} =
    ArrayNode(stabilize_types_vector(s, Matrix{T}(undef, s.n, 0)))
(s::ExtractVector)(v::HierarchicType; store_input=false) = make_missing_vector(s, v, store_input)

function (s::ExtractVector{T})(v::AbstractVector; store_input=false) where {T}
	isempty(v) && make_missing_vector(s, v, store_input)
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
	_make_array_node(stabilize_types_vector(s, x), [v], store_input)
end

Base.length(e::ExtractVector) = e.n
Base.hash(e::ExtractVector, h::UInt) = hash((e.n, e.uniontypes), h)
Base.:(==)(e1::ExtractVector, e2::ExtractVector) = e1.n === e2.n && e1.uniontypes === e2.uniontypes
