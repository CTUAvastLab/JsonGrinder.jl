"""
	struct ExtractArray{T}
		item::T
	end

Convert array of values to a `Mill.BagNode` with items converted
by `item`. The entire array is assumed to be a single bag.

# Examples

```jldoctest
julia> sc = ExtractArray(ExtractCategorical(2:4));
julia> sc([2,3,1,4]).data
4×4 ArrayNode{MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool},Nothing}:
 1  0  0  0
 0  1  0  0
 0  0  0  1
 0  0  1  0

julia> sc = ExtractArray(ExtractScalar());
julia> sc([2,3,4])
BagNode with 1 obs
  └── ArrayNode(1×3 Array, Float32) with 3 obs

julia> sc([2,3,4]).data
1×3 ArrayNode{Array{Float32,2},Nothing}:
 2.0  3.0  4.0
```
"""
struct ExtractArray{T} <: AbstractExtractor
	item::T
end

function (s::ExtractArray)(v::V) where {V<:Union{Missing, Nothing}}
	Mill._emptyismissing[] && return(BagNode(missing, [0:-1]))
	BagNode(s.item(extractempty), [0:-1])
end

(s::ExtractArray)(v::V) where {V<:Vector} = isempty(v) ? s(missing) : BagNode(reduce(catobs, map(s.item, v)),[1:length(v)])
(s::ExtractArray)(v) = s(missing)
(s::ExtractArray)(v::ExtractEmpty) = BagNode(s.item(extractempty), Mill.AlignedBags(Array{UnitRange{Int64},1}()))

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
