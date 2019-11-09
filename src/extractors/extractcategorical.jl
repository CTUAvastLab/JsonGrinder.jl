"""
	struct ExtractCategorical{T}
		datatype::Type{T}
		items::T
	end

	Convert scalar to one-hot encoded array.
"""
struct ExtractCategorical{T,I<:Dict} <: AbstractExtractor
	datatype::Type{T}
	keyvalemap::I
	n::Int
end

ExtractCategorical(T,s::Entry) = ExtractCategorical(T, keys(s.counts))
ExtractCategorical(T,s::UnitRange) = ExtractCategorical(T,collect(s))
function ExtractCategorical(ks::Vector)
	if isempty(ks)
		@warn "Skipping initializing empty categorical variable does not make much sense to me"
		return(nothing)
	end
	ks = sort(unique(ks));
	T = typeof(ks[1])
	ExtractCategorical(Float32, Dict{T, Int}(zip(ks, 1:length(ks))), length(ks) +1)
end


extractsmatrix(s::ExtractCategorical) = false
dimension(s::ExtractCategorical)  = s.n
function (s::ExtractCategorical)(v)
	x = sparse([get(s.keyvalemap, v, s.n)], [1], [true], s.n, 1)
	ArrayNode(x)
end

function (s::ExtractCategorical)(vs::Vector)
	is = [get(s.keyvalemap, v, s.n) for v in  vs]
	js = fill(1, length(is))
	vs = fill(true, length(is))
	x = sparse(is, js, vs, s.n, 1)
	ArrayNode(x)
end

(s::ExtractCategorical)(v::V) where {V<:Nothing} =  ArrayNode(spzeros(Bool, s.n, 1))
function Base.show(io::IO, m::ExtractCategorical;pad = [], key::String="") 
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "; 
	paddedprint(io,"$(key)Categorical d = $(m.n)\n", color = c, pad = pad)
end


