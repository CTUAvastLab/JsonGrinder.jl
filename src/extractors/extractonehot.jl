using SparseArrays, FillArrays, Mill

"""
	ExtractOneHot(ks, k, v)

	Converts a Vector of `Dict` items to one-hot encoding by using key 
	`k` to identify a name of item out of `ks` and values 
	of key `v` as values. 

```juliadoctest
julia> samples = ["{\"name\": \"a\", \"count\" : 1}",
		"{\"name\": \"b\", \"count\" : 2}",];
julia> samples = JSON.parse.(samples);
julia> e = ExtractOneHot(["a","b"], "name", "count");
julia> e(vs).data
3×1 SparseArrays.SparseMatrixCSC{Int64,Int64} with 2 stored entries:
  [1, 1]  =  1
  [2, 1]  =  2	
```

	If `v` is equal to `nothing`, then it boils down to one-hot encoding
```juliadoctest
julia> e = ExtractOneHot(["a","b"], "name", nothing);
julia> e(vs).data
3×1 SparseArrays.SparseMatrixCSC{Int64,Int64} with 2 stored entries:
  [1, 1]  =  1
  [2, 1]  =  1	
```

	If there is key in the data which is not known (it was not part of `vs`),
	than it is assigned to an special designed key serving as "unknown`
```juliadoctest
julia> vs = JSON.parse.(["{\"name\": \"c\", \"count\" : 1}"]);
julia> e = ExtractOneHot(["a","b"], "name", nothing);
julia> e(vs).data
3×1 SparseArrays.SparseMatrixCSC{Bool,Int64} with 1 stored entry:
  [3, 1]  =  1

```
"""
struct ExtractOneHot{K,I,V} <: AbstractExtractor
	k::K
	v::V
	key2id::Dict{I,Int}
	n::Int
end

dimension(e::ExtractOneHot) = e.n
extractsmatrix(s::ExtractOneHot) = false

function ExtractOneHot(ks::V, k, v = nothing) where {V<:Union{Vector, Set}}
	key2id = Dict(zip(ks, 1:length(ks)))
	ExtractOneHot(k, v, key2id, length(key2id) + 1)
end

(e::ExtractOneHot{K,V})(v::Dict) where {K, V} = ArrayNode(sparse([e.key2id[v[e.k]]],  [1f0], [get(v, e.v, 0)], e.n))


(e::ExtractOneHot{K,I,V})(v::Dict) where {K, I, V <:Nothing} = ArrayNode(sparse([e.key2id[v[e.k]]], [1f0], true, e.n))

function (e::ExtractOneHot{K,I,V})(vs::Vector) where {K, I, V<:Nothing}
	isempty(vs) && return(ArrayNode(spzeros(Float32, e.n, 1)))
	ids = [get(e.key2id, v[e.k], e.n) for v in vs]
	ArrayNode(sparse(ids, Ones(length(ids)), true, e.n, 1))
end

function (e::ExtractOneHot{K,I,V})(vs::Vector) where {K, I, V}
	isempty(vs) && return(ArrayNode(spzeros(Float32, e.n, 1)))
	ids = [get(e.key2id, v[e.k], e.n) for v in vs]
	x = [Float32(v[e.v]) for v in vs]
	ArrayNode(sparse(ids, Ones(length(ids)), x, e.n, 1))
end


(e::ExtractOneHot)(::Nothing) = ArrayNode(spzeros(Float32, e.n, 1))
(e::ExtractOneHot{K,I,V})(::Nothing) where {K, I, V <:Nothing} = ArrayNode(spzeros(Bool, e.n, 1))