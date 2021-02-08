"""
	struct ExtractScalar{T}
		c::T
		s::T
		full::Bool
	end

Extracts a numerical value, centred by subtracting `c` and scaled by multiplying by `s`.
Strings are converted to numbers.

The extractor returns `ArrayNode{Matrix{Union{Missing, Int64}},Nothing}` or it subtypes.
If passed `missing`, it extracts missing values which Mill understands and can work with.

The `full` field determines whether extractor may or may not accept `missing`. If `full` is true, it does not accept
missing values. If `full` is false, it accepts missing values, and always returns Mill structure of type
Union{Missing, T} due to type stability reasons.

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
	full::Bool
end


ExtractScalar(T = Float32) = ExtractScalar(zero(T), one(T), true)
ExtractScalar(T, c, s, full = true) = ExtractScalar(T(c), T(s), full)

extractscalar(::Type{T}, m = zero(T), s = one(T), full = true) where {T<:Number} = ExtractScalar(T, m, s, full)
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
	ExtractScalar(Float32(c), Float32(s))
end

(s::ExtractScalar{T})(v::W) where {T,W<:Union{Missing, Nothing}} = ArrayNode(fill(missing,(1,1)))
(s::ExtractScalar{T})(v::W) where {T,W<:ExtractEmpty} = ArrayNode(fill(zero(T),(1,0)))
(s::ExtractScalar{T})(v::Number) where {T} = ArrayNode(s.s .* (fill(T(v),1,1) .- s.c))
(s::ExtractScalar{T})(v::AbstractString) where{T} = s((tryparse(T,v)))
(s::ExtractScalar)(v) = s(missing)

Base.length(e::ExtractScalar) = 1

# data type has different hashes for each patch version of julia
# see https://discourse.julialang.org/t/datatype-hash-differs-per-patch-version/48827
Base.hash(e::ExtractScalar{T}, h::UInt) where {T} = hash((e.c, e.s, e.full), h)
Base.:(==)(e1::ExtractScalar{T}, e2::ExtractScalar{T}) where {T} = e1.c === e2.c && e1.s === e2.s && e1.full === e2.full
