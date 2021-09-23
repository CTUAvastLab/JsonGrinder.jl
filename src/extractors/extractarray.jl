"""
	struct ExtractArray{T}
		item::T
	end

	convert array of values to one bag of values converted with `item`. Note that in order the function to work properly,
	calling `item` on a single item has to return Matrix.

```juliadoctest
julia> sc = ExtractArray(ExtractCategorical(Float32,2:4))
julia> sc([2,3,1,4]).data
3×4 Array{Float32,2}:
 1.0  0.0  0.0  0.0
 0.0  1.0  0.0  0.0
 0.0  0.0  0.0  1.0

```

```juliadoctest
julia> sc = ExtractArray(ExtractScalar())
julia> sc([2,3,4]).data
 2.0  3.0  4.0
```
"""
struct ExtractArray{T} <: AbstractExtractor
	item::T
end

extractsmatrix(s::ExtractArray) = false

function (s::ExtractArray)(v::V; store_input=false) where {V<:Union{Missing, Nothing}}
	Mill._emptyismissing[] && return BagNode(missing, [0:-1])
	ds = s.item(nothing, store_input=store_input)[1:0]
	BagNode(ds, [0:-1])
end

(s::ExtractArray)(v::V; store_input=false) where {V<:Vector} =
	isempty(v) ? s(nothing, store_input=store_input) : BagNode(reduce(catobs, map(x->s.item(x, store_input=store_input), v)),[1:length(v)])

function (s::ExtractArray)(v; store_input=false)
	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
	Mill._emptyismissing[] && return store_input ? BagNode(missing, [0:-1]) : BagNode(missing, [0:-1], [v])
	ds = s.item(nothing, store_input=store_input)[1:0]
	store_input ? BagNode(ds, [0:-1]) : BagNode(ds, [0:-1], [v])
end

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
