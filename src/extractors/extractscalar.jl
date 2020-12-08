"""
	struct ExtractScalar{T}
		c::T
		s::T
	end

	extract a scalar value and center. If `T` is of type number, it is centered by first subtracting c and then
	multiplying that with s.
"""
struct ExtractScalar{T} <: AbstractExtractor
	c::T
	s::T
end

ExtractScalar(T) = ExtractScalar(zero(T), one(T))
ExtractScalar(T, c, s) = ExtractScalar(T(c), T(s))
extractsmatrix(s::ExtractScalar) = true

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
	ExtractScalar(Float32(c), Float32(s))
end
# todo: dodělat missingy, všchny nothing předělat na missing a pořádně to otestovat
(s::ExtractScalar{T})(v::W) where {T,W<:Union{Missing, Nothing}} = ArrayNode(fill(missing,(1,1)))
(s::ExtractScalar{T})(v::Number) where {T} = ArrayNode(s.s .* (fill(T(v),1,1) .- s.c))
(s::ExtractScalar{T})(v::AbstractString) where{T} = s((tryparse(T,v)))
(s::ExtractScalar)(v)  = s(missing)

Base.length(e::ExtractScalar) = 1
# data type has different hashes for each patch version of julia
# see https://discourse.julialang.org/t/datatype-hash-differs-per-patch-version/48827
Base.hash(e::ExtractScalar{T}, h::UInt) where {T} = hash((e.c, e.s), h)
Base.:(==)(e1::ExtractScalar{T}, e2::ExtractScalar{T}) where {T} = e1.c === e2.c && e1.s === e2.s
