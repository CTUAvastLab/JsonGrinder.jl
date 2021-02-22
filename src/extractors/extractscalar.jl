"""
	struct ExtractScalar{T}
		c::T
		s::T
	end

Extracts a numerical value, centred by subtracting `c` and scaled by multiplying by `s`.
Strings are converted to numbers.

The extractor returns `ArrayNode{Matrix{Union{Missing, Int64}},Nothing}` or it subtypes.
If passed `missing`, it extracts missing values which Mill understands and can work with.

It can be created also using `extractscalar(Float32, 5, 2)`

# Example
```jldoctest
julia> ExtractScalar(Float32, 2, 3)(1)
1×1 Mill.ArrayNode{Array{Float32,2},Nothing}:
 -3.0

julia> ExtractScalar(Float32, 2, 3)(missing)
1×1 Mill.ArrayNode{Array{Missing,2},Nothing}:
 missing
```
"""
struct ExtractScalar{T} <: AbstractExtractor
	c::T
	s::T
end


ExtractScalar(T = Float32) = ExtractScalar(zero(T), one(T))
ExtractScalar(T, c, s) = ExtractScalar(T(c), T(s))

extractscalar(::Type{T}, m = zero(T), s = one(T)) where {T<:Number} = ExtractScalar(T, m, s)
function extractscalar(::Type{T}, e::Entry) where {T<:Number}
	if unify_types(e) <: AbstractString
		values = parse.(T, keys(e.counts))
	else
		values = keys(e.counts)
	end
	min_val = minimum(values)
	max_val = maximum(values)
	c = min_val
	s = max_val == min_val ? 1 : 1 / (max_val - min_val)
	ExtractScalar(FloatType(c), FloatType(s))
end

_fill_and_normalize(s::ExtractScalar{T}, v::T) where {T} = s.s .* (fill(v,1,1) .- s.c)
make_missing_scalar(s::ExtractScalar, v, store_input) = _make_array_node(fill(missing,1,1), fill(v,1,1), store_input)

(s::ExtractScalar{T})(v::MissingOrNothing; store_input=false) where {T} = make_missing_scalar(s, v, store_input)
(s::ExtractScalar{T})(v::ExtractEmpty; store_input=false) where {T} = ArrayNode(fill(zero(T),1,0))
(s::ExtractScalar{T})(v::Number; store_input=false) where {T} =
	_make_array_node(_fill_and_normalize(s, T(v)), fill(v,1,1), store_input)
(s::ExtractScalar)(v; store_input=false) = make_missing_scalar(s, v, store_input)
function (s::ExtractScalar{T})(v::AbstractString; store_input=false) where {T}
	w = tryparse(T,v)
	isnothing(w) && return make_missing_scalar(s, v, store_input)
	x = _fill_and_normalize(s, T(w))
	_make_array_node(x, fill(v,1,1), store_input)
end

Base.length(e::ExtractScalar) = 1

# data type has different hashes for each patch version of julia
# see https://discourse.julialang.org/t/datatype-hash-differs-per-patch-version/48827
Base.hash(e::ExtractScalar{T}, h::UInt) where {T} = hash((e.c, e.s), h)
Base.:(==)(e1::ExtractScalar{T}, e2::ExtractScalar{T}) where {T} = e1.c === e2.c && e1.s === e2.s
