"""
	struct ExtractCategorical{T}
		datatype::Type{T}
		items::T
	end

	Convert scalar to one-hot encoded array.
"""
struct ExtractCategorical{T,I<:Vector} <: AbstractExtractor
	datatype::Type{T}
	items::I
end

ExtractCategorical(T,s::Entry) = ExtractCategorical(T, keys(s.counts))
ExtractCategorical(T,s::UnitRange) = ExtractCategorical(T,collect(s))
function ExtractCategorical(ks)
	isempty(ks) && @warn "Initializing empty categorical variable does not make much sense to me"
	ks = unique(ks);
	T = isempty(ks) ? typeof(k) : typeof(ks[1])
	ExtractCategorical(Float32, Dict{T, Int}(zip(ks, 1:length(ks))))
end


extractsmatrix(s::ExtractCategorical) = false
dimension(s::ExtractCategorical)  = dimension(s.items)
function (s::ExtractCategorical)(v) 
	x = zeros(s.datatype,length(s.items), 1)
	i = findfirst(isequal(v),s.items)
	if i != nothing
		x[i] = 1
	end
	ArrayNode(x)
end

(s::ExtractCategorical)(v::V) where {V<:Nothing} =  ArrayNode(zeros(s.datatype,length(s.items), 1))
function Base.show(io::IO, m::ExtractCategorical;pad = [], key::String="") 
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "; 
	paddedprint(io,"$(key)Categorical\n", color = c, pad = pad)
end
