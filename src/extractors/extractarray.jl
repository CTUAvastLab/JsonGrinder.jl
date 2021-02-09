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
4×4 Mill.ArrayNode{Mill.MaybeHotMatrix{Union{Missing, Int64},Int64,Union{Missing, Bool}},Nothing}:
  true  false  false  false
 false   true  false  false
 false  false  false   true
 false  false   true  false

julia> es = ExtractArray(ExtractScalar());

julia> es([2,3,4])
BagNode with 1 obs
  └── ArrayNode(1×3 Array with Union{Missing, Float32} elements) with 3 obs

julia> es([2,3,4]).data
1×3 Mill.ArrayNode{Array{Union{Missing, Float32},2},Nothing}:
 2.0f0  3.0f0  4.0f0
```
"""
struct ExtractArray{T} <: AbstractExtractor
	item::T
end

function (s::ExtractArray)(v::V) where {V<:MissingOrNothing}
	Mill._emptyismissing[] && return BagNode(missing, [0:-1])
	BagNode(s.item(extractempty), [0:-1])
end

(s::ExtractArray)(v::V) where {V<:Vector} = isempty(v) ? s(missing) : BagNode(reduce(catobs, map(s.item, v)),[1:length(v)])
(s::ExtractArray)(v) = s(missing)
(s::ExtractArray)(v::ExtractEmpty) = BagNode(s.item(extractempty), Mill.AlignedBags(Vector{UnitRange{Int64}}()))

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
