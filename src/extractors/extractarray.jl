"""
	struct ExtractArray{T}
		item::T
	end

Convert array of values to a `Mill.BagNode` with items converted
by `item`. The entire array is assumed to be a single bag.

# Examples

```jldoctest
julia> ec = ExtractArray(ExtractCategorical(2:4));

julia> ec([2,3,1,4]).data
4×4 Mill.ArrayNode{Mill.MaybeHotMatrix{Int64,Int64,Bool},Nothing}:
 1  0  0  0
 0  1  0  0
 0  0  0  1
 0  0  1  0

julia> es = ExtractArray(ExtractScalar());

julia> es([2,3,4])
BagNode with 1 obs
  └── ArrayNode(1×3 Array with Float32 elements) with 3 obs

julia> es([2,3,4]).data
1×3 Mill.ArrayNode{Array{Float32,2},Nothing}:
 2.0  3.0  4.0
```
"""
struct ExtractArray{T} <: AbstractExtractor
	item::T
end

function extract_empty_bag(s::ExtractArray, v; store_input=false)
	Mill._emptyismissing[] && return store_input ? BagNode(missing, [0:-1]) : BagNode(missing, [0:-1], [v])
	ds = s.item(extractempty; store_input)
	store_input ? BagNode(ds, [0:-1]) : BagNode(ds, [0:-1], [v])
end

(s::ExtractArray)(v::MissingOrNothing; store_input=false) = extract_empty_bag(s, v; store_input)

(s::ExtractArray)(v::V, store_input=false) where {V<:Vector} =
    isempty(v) ? s(missing; store_input) : BagNode(mapreduce(x->s.item(x; store_input), catobs, v),[1:length(v)])
(s::ExtractArray)(v; store_input=false) = extract_empty_bag(s, v; store_input)

(s::ExtractArray)(v::ExtractEmpty, store_input=false) =
    BagNode(s.item(extractempty; store_input), Mill.AlignedBags(Vector{UnitRange{Int64}}()))

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
