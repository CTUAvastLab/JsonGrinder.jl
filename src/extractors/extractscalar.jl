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
	c = convert(FloatType, min_val)
	s = max_val == min_val ? convert(FloatType, 1) : convert(FloatType, 1 / (max_val - min_val))
	ExtractScalar(FloatType, c, s)
end

function (s::ExtractScalar{T,V})(v::Nothing; store_input=false) where {T,V}
	x = fill(zero(T),1,1)
	store_input ? ArrayNode(x, fill(v,1,1)) : ArrayNode(x)
end
function (s::ExtractScalar)(v::Number; store_input=false)
	x = s.s .* (fill(s.datatype(v),1,1) .- s.c)
	store_input ? ArrayNode(x, fill(v,1,1)) : ArrayNode(x)
end
function (s::ExtractScalar{T,V})(v::AbstractString; store_input=false) where {T,V}
	# logic for normalization is duplicated here, because I need to store metadata before it's parsed
	w = tryparse(s.datatype, v)
	# this should definitely be written more nicely, but for now it suffices
	if isnothing(w)
		x = fill(zero(T),1,1)
		return store_input ? ArrayNode(x, fill(v,1,1)) : ArrayNode(x)
	end
	x = s.s .* (fill(s.datatype(w),1,1) .- s.c)
	store_input ? ArrayNode(x, fill(v,1,1)) : ArrayNode(x)
# todo: všude projít, že tam budu posílat orig. hodnotu
end
function (s::ExtractScalar{T,V})(v; store_input=false) where {T,V}
	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
	x = fill(zero(T),(1,1))
	store_input ? ArrayNode(x, fill(v,1,1)) : ArrayNode(x)
end
Base.length(e::ExtractScalar) = 1
Base.hash(e::ExtractScalar, h::UInt) = hash((e.datatype, e.c, e.s), h)
Base.:(==)(e1::ExtractScalar, e2::ExtractScalar) = e1.datatype == e2.datatype && e1.c === e2.c && e1.s === e2.s
