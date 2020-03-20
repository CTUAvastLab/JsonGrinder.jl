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

ExtractBranch{Dict,Dict} <: ExtractBranch
Type{ExtractBranch{Dict,Dict}} isa ExtractBranch
ExtractScalar(datatype) = ExtractScalar(datatype, zero(datatype), one(datatype))
extractsmatrix(s::ExtractScalar) = true

(s::ExtractScalar{T,V})(v) where {T<:Number,V}			 = ArrayNode(s.s .* (fill(s.datatype(v),1,1) .- s.c))
(s::ExtractScalar{T,V} where {V,T<:Number})(v::String)   = s((parse(s.datatype,v)))
(s::ExtractScalar{T,V})(v::S) where {T<:Number,V,S<:Nothing}= ArrayNode(fill(zero(T),(1,1)))

Base.hash(e::ExtractScalar, h::UInt) = hash((e.datatype, e.c, e.s), h)
Base.:(==)(e1::ExtractScalar, e2::ExtractScalar) = e1.datatype == e2.datatype && e1.c === e2.c && e1.s === e2.s
