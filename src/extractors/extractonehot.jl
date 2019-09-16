using SparseArrays, FillArrays, Mill

"""

	Converts a Vector of `Dict` items to one-hot encoding. 

"""
struct ExtractOneHot{K,I,V} <: AbstractExtractor
	k::K
	v::V
	key2id::Dict{I,Int}
	n::Int
end

dimension(e::ExtractOneHot) = e.n
extractsmatrix(s::ExtractOneHot) = false

function ExtractOneHot(vs::Vector, k) 
	key2id = buildkey2id(k, vs)
	ExtractOneHot(k, nothing, key2id , length(key2id))
end

function ExtractOneHot(vs::Vector, k, v) 
	key2id = buildkey2id(k, vs)
	ExtractOneHot(k, v, key2id, length(key2id))
end

(e::ExtractOneHot{K,V})(v::Dict) where {K, V <:Nothing} = ArrayNode(sparse([e.key2id[v[e.k]]], [1],true, e.n))
(e::ExtractOneHot{K,V})(v::Dict) where {K, V} = ArrayNode(sparse([e.key2id[v[e.k]]],  [1], [get(v, e.v, 0)], e.n))

function (e::ExtractOneHot{K,I,V})(vs::Vector) where {K, I, V<:Nothing}
	isempty(vs) && return(ArrayNode(spzeros(Float32, e.n, 1)))
	ids = [e.key2id[v[e.k]] for v in vs]
	ArrayNode(sparse(ids, Ones(length(ids)), true, e.n, 1))
end

function (e::ExtractOneHot{K,I,V})(vs::Vector) where {K, I, V}
	isempty(vs) && return(spzeros(Float32, e.n))
	ids = [e.key2id[v[e.k]] for v in vs]
	x = [v[e.v] for v in vs]
	ArrayNode(sparse(ids, Ones(length(ids)), x, e.n, 1))
end


#helper functions for easire construction of the extractor
identifyallkeys(k, v::Dict) = get(v, k, nothing)
function identifyallkeys(k, vs) 
	ks = map(v -> identifyallkeys(k, v), vs)
	ks = filter(s -> s != nothing, ks)
	ks = isempty(ks) ? ks : reduce(union, ks)
	ks
end

function buildkey2id(k, vs)
	ks = sort(identifyallkeys(k, vs))
	T = isempty(ks) ? typeof(k) : typeof(ks[1])
	Dict{T, Int}(zip(ks, 1:length(ks)))
end
