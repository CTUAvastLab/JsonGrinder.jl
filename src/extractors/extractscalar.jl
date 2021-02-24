"""
	struct ExtractScalar{T} <: AbstractExtractor
		c::T
		s::T
		uniontypes::Bool
	end

Extracts a numerical value, centred by subtracting `c` and scaled by multiplying by `s`.
Strings are converted to numbers.

The extractor returns `ArrayNode{Matrix{Union{Missing, Int64}},Nothing}` or it subtypes.
If passed `missing`, it extracts missing values which Mill understands and can work with.

The `uniontypes` field determines whether extractor may or may not accept `missing`.
If `uniontypes` is false, it does not accept missing values. If `uniontypes` is true, it accepts missing values,
and always returns Mill structure of type Union{Missing, T} due to type stability reasons.

It can be created also using `extractscalar(Float32, 5, 2)`

# Example
```jldoctest
julia> ExtractScalar(Float32, 2, 3, true)(1)
1×1 Mill.ArrayNode{Array{Union{Missing, Float32},2},Nothing}:
 -3.0f0

julia> ExtractScalar(Float32, 2, 3, true)(missing)
1×1 Mill.ArrayNode{Array{Union{Missing, Float32},2},Nothing}:
 missing

julia> ExtractScalar(Float32, 2, 3, false)(1)
1×1 Mill.ArrayNode{Array{Float32,2},Nothing}:
 -3.0

```
"""
struct ExtractScalar{T} <: AbstractExtractor
	c::T
	s::T
	uniontypes::Bool
end


ExtractScalar(T = Float32) = ExtractScalar(zero(T), one(T), true)
ExtractScalar(T, c, s, uniontypes = true) = ExtractScalar(T(c), T(s), uniontypes)

extractscalar(::Type{T}, m = zero(T), s = one(T), uniontypes = true) where {T<:Number} = ExtractScalar(T, m, s, uniontypes)
extractscalar(::Type{T}, uniontypes::Bool) where {T<:Number} = ExtractScalar(T, zero(T), one(T), uniontypes)
function extractscalar(::Type{T}, e::Entry, uniontypes = true) where {T<:Number}
	if unify_types(e) <: AbstractString
		values = parse.(T, keys(e.counts))
	else
		values = keys(e.counts)
	end
	min_val = minimum(values)
	max_val = maximum(values)
	c = min_val
	s = max_val == min_val ? 1 : 1 / (max_val - min_val)
	ExtractScalar(Float32(c), Float32(s), uniontypes)
end

_fill_and_normalize(s::ExtractScalar{T}, v::T) where {T} = s.s .* (fill(v,1,1) .- s.c)
stabilize_types_scalar(s::ExtractScalar{T}, x) where {T} = s.uniontypes ? Matrix{Union{Missing, T}}(data) : data
make_missing_scalar(s::ExtractScalar{T}, v, store_input) where {T} =
	s.uniontypes ?
	_make_array_node(Matrix{Union{Missing, T}}(fill(missing,1,1)), fill(v,1,1), store_input) :
	error("This extractor does not support missing values")
make_empty_scalar(s::ExtractScalar{T}, store_input) where {T} =
	_make_array_node(stabilize_types_scalar(s, fill(zero(T),1,0)), fill(undef,1,0), store_input)

(s::ExtractScalar)(v; store_input=false) = make_missing_scalar(s, v, store_input)
(s::ExtractScalar{T})(v::MissingOrNothing; store_input=false) where {T} = make_missing_scalar(s, v, store_input)
(s::ExtractScalar{T})(v::ExtractEmpty; store_input=false) where {T} = make_empty_scalar(s, store_input)
(s::ExtractScalar{T})(v::Number; store_input=false) where {T} =
	_make_array_node(stabilize_types_scalar(s, _fill_and_normalize(s, T(v))), fill(v,1,1), store_input)
function (s::ExtractScalar{T})(v::AbstractString; store_input=false) where {T}
	w = tryparse(T,v)
	isnothing(w) && return make_missing_scalar(s, v, store_input)
	_make_array_node(stabilize_types_scalar(s, _fill_and_normalize(s, T(w))), fill(v,1,1), store_input)
end
(s::ExtractScalar)(v; store_input=false) = make_missing_scalar(s, v, store_input)

Base.length(e::ExtractScalar) = 1

# data type has different hashes for each patch version of julia
# see https://discourse.julialang.org/t/datatype-hash-differs-per-patch-version/48827
Base.hash(e::ExtractScalar{T}, h::UInt) where {T} = hash((e.c, e.s, e.uniontypes), h)
Base.:(==)(e1::ExtractScalar{T}, e2::ExtractScalar{T}) where {T} = e1.c === e2.c && e1.s === e2.s && e1.uniontypes === e2.uniontypes
