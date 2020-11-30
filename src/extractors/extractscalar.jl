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

ExtractScalar(datatype) = ExtractScalar(zero(datatype), one(datatype))
extractsmatrix(s::ExtractScalar) = true

function extractscalar(::Type{T}, e::Entry) where {T<:Number}
	if unify_types(e) <: AbstractString
		values = parse.(T, keys(e.counts))
	else
		values = keys(e.counts)
	end
	min_val = minimum(values)
	max_val = maximum(values)
	c = convert(FloatType, min_val)
	s = max_val == min_val ? convert(FloatType, 1) : convert(FloatType, 1 / (max_val - min_val))
	ExtractScalar(FloatType, c, s)
end
# todo: dodělat missingy, všchny nothing předělat na missing a pořádně to otestovat
(s::ExtractScalar{T,V})(v::W) where {T,V,W<:Union{Missing, Nothing}} = ArrayNode(fill(missing,(1,1)))
(s::ExtractScalar)(v::Number) = ArrayNode(s.s .* (fill(s.datatype(v),1,1) .- s.c))
(s::ExtractScalar)(v::AbstractString) = s((tryparse(s.datatype,v)))
(s::ExtractScalar{T,V})(v) where {T,V} = s(missing)

Base.length(e::ExtractScalar) = 1
# data type has different hashes for each patch version of julia
# see https://discourse.julialang.org/t/datatype-hash-differs-per-patch-version/48827
Base.hash(e::ExtractScalar, h::UInt) = hash((string(e.datatype), e.c, e.s), h)
Base.:(==)(e1::ExtractScalar, e2::ExtractScalar) = e1.datatype == e2.datatype && e1.c === e2.c && e1.s === e2.s
