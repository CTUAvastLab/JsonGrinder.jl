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

function ExtractOneHot(vs::V, k, v = nothing) where {V<:Union{Vector, Set}}
	key2id = Dict(zip(vs, 1:length(vs)))
	ExtractOneHot(k, v, key2id, length(key2id) + 1)
end

(e::ExtractOneHot{K,V})(v::Dict) where {K, V <:Nothing} = ArrayNode(sparse([e.key2id[v[e.k]]], [1],true, e.n))
(e::ExtractOneHot{K,V})(v::Dict) where {K, V} = ArrayNode(sparse([e.key2id[v[e.k]]],  [1], [get(v, e.v, 0)], e.n))

function (e::ExtractOneHot{K,I,V})(vs::Vector) where {K, I, V<:Nothing}
	isempty(vs) && return(ArrayNode(spzeros(Float32, e.n, 1)))
	ids = [get(e.key2id, v[e.k], e.n) for v in vs]
	ArrayNode(sparse(ids, Ones(length(ids)), true, e.n, 1))
end

function (e::ExtractOneHot{K,I,V})(vs::Vector) where {K, I, V}
	isempty(vs) && return(spzeros(Float32, e.n, 1))
	ids = [get(e.key2id, v[e.k], e.n) for v in vs]
	x = [v[e.v] for v in vs]
	ArrayNode(sparse(ids, Ones(length(ids)), x, e.n, 1))
end


(e::ExtractOneHot)(::Nothing) = spzeros(Float32, e.n, 1)