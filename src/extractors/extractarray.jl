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

"""
returns missing bag of 1 observation
"""
function extract_missing_bag(s::ExtractArray, v; store_input=false)
	Mill._emptyismissing[] && return _make_bag_node(missing, [0:-1], [v], store_input)
	ds = s.item(extractempty; store_input)
	_make_bag_node(ds, [0:-1], [v], store_input)
end

(s::ExtractArray)(v::MissingOrNothing; store_input=false) = extract_missing_bag(s, v; store_input)

(s::ExtractArray)(v::Vector; store_input=false) =
    isempty(v) ?
	extract_missing_bag(s, v; store_input) :
	BagNode(mapreduce(x->s.item(x; store_input), catobs, v),[1:length(v)])
(s::ExtractArray)(v; store_input=false) = extract_missing_bag(s, v; store_input)

(s::ExtractArray)(v::ExtractEmpty; store_input=false) = make_empty_bag(s.item(extractempty; store_input), v)

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
