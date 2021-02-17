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

(s::ExtractScalar{T})(v::W; store_input=false) where {T,W<:MissingOrNothing} = ArrayNode(fill(missing,(1,1)))
(s::ExtractScalar{T})(v::W; store_input=false) where {T,W<:ExtractEmpty} = ArrayNode(fill(zero(T),(1,0)))
(s::ExtractScalar{T})(v::Number; store_input=false) where {T} = ArrayNode(s.s .* (fill(T(v),1,1) .- s.c))
(s::ExtractScalar{T})(v::AbstractString; store_input=false) where{T} = s((tryparse(T,v)))
(s::ExtractScalar)(v; store_input=false) = s(missing)



function (s::ExtractScalar{T,V})(v::AbstractString; store_input=false) where {T,V}
	# logic for normalization is duplicated here, because I need to store metadata before it's parsed
	w = tryparse(s.datatype, v)
	# this should definitely be written more nicely, but for now it suffices
	if isnothing(w)
		x = fill(zero(T),(1,1))
		return store_input ? ArrayNode(x, [v]) : ArrayNode(x)
	end
	x = s.s .* (fill(s.datatype(w),1,1) .- s.c)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
# todo: všude projít, že tam budu posílat orig. hodnotu
end
function (s::ExtractScalar{T,V})(v; store_input=false) where {T,V}
	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
	x = fill(zero(T),(1,1))
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end
Base.length(e::ExtractScalar) = 1

# data type has different hashes for each patch version of julia
# see https://discourse.julialang.org/t/datatype-hash-differs-per-patch-version/48827
Base.hash(e::ExtractScalar{T}, h::UInt) where {T} = hash((e.c, e.s), h)
Base.:(==)(e1::ExtractScalar{T}, e2::ExtractScalar{T}) where {T} = e1.c === e2.c && e1.s === e2.s
