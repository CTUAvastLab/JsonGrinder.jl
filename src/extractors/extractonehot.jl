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

extractsmatrix(s::ExtractOneHot) = false

function ExtractOneHot(ks::V, k, v = nothing) where {V<:Union{Vector, Set}}
	key2id = Dict(zip(ks, 1:length(ks)))
	ExtractOneHot(k, v, key2id, length(key2id) + 1)
end

function (e::ExtractOneHot{K,V})(v::Dict; store_input=false) where {K, V <:Nothing}
	x = sparse([e.key2id[v[e.k]]], [1f0], true, e.n)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end

function (e::ExtractOneHot{K,V})(v::Dict; store_input=false) where {K, V}
	x = sparse([e.key2id[v[e.k]]],  [1f0], [get(v, e.v, 0)], e.n)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end

function (e::ExtractOneHot{K,I,V})(vs::Vector; store_input=false) where {K, I, V<:Nothing}
	if isempty(vs)
		x = spzeros(Float32, e.n, 1)
		return store_input ? ArrayNode(x, [vs]) : ArrayNode(x)
	end
	ids = [get(e.key2id, v[e.k], e.n) for v in vs]
	x = sparse(ids, Ones(length(ids)), 1f0, e.n, 1)
	store_input ? ArrayNode(x, [vs]) : ArrayNode(x)
end

function (e::ExtractOneHot{K,I,V})(vs::Vector; store_input=false) where {K, I, V}
	isempty(vs) && return(ArrayNode(spzeros(Float32, e.n, 1)))
	ids = [get(e.key2id, v[e.k], e.n) for v in vs]
	x = [Float32(v[e.v]) for v in vs]
	val = sparse(ids, Ones(length(ids)), x, e.n, 1)
	store_input ? ArrayNode(val, [vs]) : ArrayNode(val)
end

function (e::ExtractOneHot)(v::Nothing; store_input=false)
	x = spzeros(Float32, e.n, 1)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end
function (e::ExtractOneHot)(v; store_input=false)
	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
	x = spzeros(Float32, e.n, 1)
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end

Base.hash(e::ExtractOneHot, h::UInt) = hash((e.k, e.v, e.key2id, e.n), h)
Base.:(==)(e1::ExtractOneHot, e2::ExtractOneHot) = e1.k === e2.k && e1.v === e2.v && e1.key2id == e2.key2id && e1.n === e2.n
