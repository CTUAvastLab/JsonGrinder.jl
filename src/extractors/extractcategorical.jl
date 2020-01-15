"""
	ExtractCategorical(s::Entry)
	ExtractCategorical(s::UnitRange)
	ExtractCategorical(s::Vector)

	Converts a single item to a one-hot encoded vector. There is always alocated an extra
	element for a unknown value
"""
struct ExtractCategorical{I<:Dict} <: AbstractExtractor
	keyvalemap::I
	n::Int
end

ExtractCategorical(s::Entry) = ExtractCategorical(keys(s.counts))
ExtractCategorical(s::UnitRange) = ExtractCategorical(collect(s))
function ExtractCategorical(ks::Vector)
	if isempty(ks)
		@warn "Skipping initializing empty categorical variable does not make much sense to me"
		return(nothing)
	end
	ks = sort(unique(ks));
	T = typeof(ks[1])
	ExtractCategorical(Dict{T,Int}(zip(ks, 1:length(ks))), length(ks) +1)
end


extractsmatrix(s::ExtractCategorical) = false

function (s::ExtractCategorical)(v)
	x = sparse([get(s.keyvalemap, v, s.n)], [1], [1f0], s.n, 1)
	ArrayNode(x)
end

function (s::ExtractCategorical)(vs::Vector)
	is = [get(s.keyvalemap, v, s.n) for v in  vs]
	js = fill(1, length(is))
	vs = fill(1f0, length(is))
	x = sparse(is, js, vs, s.n, 1)
	ArrayNode(x)
end

(s::ExtractCategorical)(v::V) where {V<:Nothing} =  ArrayNode(spzeros(Float32, s.n, 1))
function Base.show(io::IO, m::ExtractCategorical;pad = [], key::String="")
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": ";
	paddedprint(io,"$(key)Categorical d = $(m.n)\n", color = c, pad = pad)
end
