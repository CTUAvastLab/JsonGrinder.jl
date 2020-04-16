"""
	struct ExtractScalar{T}
		datatype::Type{T}
		c::T
		s::T
	end

	extract a scalar value and center. If `T` is of type number, it is centered by first subtracting c and then
	multiplying that with s.
"""
struct ExtractScalar{T<:Number,V} <: AbstractExtractor
	datatype::Type{T}
	c::V
	s::V
end

ExtractScalar(datatype) = ExtractScalar(datatype, zero(datatype), one(datatype))
extractsmatrix(s::ExtractScalar) = true

function extractscalar(::Type{T}, e::Entry) where {T<:Number}
	if unify_types(e) <: AbstractString
		values = parse.(T, keys(e.counts))
	else
		values = keys(e.counts)
	end
	min_val = minimum(values)
	max_val = maximum(values)
	c = float(min_val)
	s = max_val == min_val ? 1. : float(1 / (max_val - min_val))
	ExtractScalar(T, c, s)
end

(s::ExtractScalar{T,V})(v::Nothing) where {T,V} = ArrayNode(fill(zero(T),(1,1)))
(s::ExtractScalar)(v::Number) = ArrayNode(s.s .* (fill(s.datatype(v),1,1) .- s.c))
(s::ExtractScalar)(v::AbstractString) = s((tryparse(s.datatype,v)))
(s::ExtractScalar{T,V})(v)  where {T,V} = s(nothing)

Base.hash(e::ExtractScalar, h::UInt) = hash((e.datatype, e.c, e.s), h)
Base.:(==)(e1::ExtractScalar, e2::ExtractScalar) = e1.datatype == e2.datatype && e1.c === e2.c && e1.s === e2.s
