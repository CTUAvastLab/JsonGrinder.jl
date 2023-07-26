"""
	struct ExtractArray{T}
		item::T
	end

Convert array of values to a `Mill.BagNode` with items converted
by `item`. The entire array is assumed to be a single bag.

# Examples

```jldoctest
julia> ec = ExtractArray(ExtractCategorical(2:4));

julia> ec([2, 3, 1, 4])
BagNode  # 1 obs, 88 bytes
  ╰── ArrayNode(4×4 MaybeHotMatrix with Union{Missing, Bool} elements)  # 4 obs, 92 bytes

julia> ans.data
4×4 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
  true    ⋅      ⋅      ⋅  
   ⋅     true    ⋅      ⋅
   ⋅      ⋅      ⋅     true
   ⋅      ⋅     true    ⋅

julia> es = ExtractArray(ExtractScalar());

julia> es([2,3,4])
BagNode  # 1 obs, 80 bytes
  ╰── ArrayNode(1×3 Array with Union{Missing, Float32} elements)  # 3 obs, 63 bytes

julia> es([2,3,4]).data
1×3 ArrayNode{Matrix{Union{Missing, Float32}}, Nothing}:
 2.0f0  3.0f0  4.0f0
```
"""
struct ExtractArray{T} <: BagExtractor
	item::T
end

extract_empty_bag_item(::BagExtractor, store_input) = @error "Abstract method, please, implement it for your extractor"
extract_empty_bag_item(s::ExtractArray, store_input) = s.item(extractempty; store_input)

"""
returns missing bag of 1 observation
"""
function extract_missing_bag(s::BagExtractor, v; store_input=false)
    Mill.emptyismissing() && return _make_bag_node(missing, [0:-1], [v], store_input)
    ds = extract_empty_bag_item(s, store_input)
    _make_bag_node(ds, [0:-1], [v], store_input)
end

(s::ExtractArray)(v::MissingOrNothing; store_input=false) = extract_missing_bag(s, v; store_input)

(s::ExtractArray)(v::AbstractVector; store_input=false) =
    isempty(v) ?
extract_missing_bag(s, v; store_input) :
BagNode(mapreduce(x->s.item(x; store_input), catobs, v), [1:length(v)])
(s::ExtractArray)(v::HierarchicType; store_input=false) = extract_missing_bag(s, v; store_input)

(s::ExtractArray)(v::ExtractEmpty; store_input=false) = make_empty_bag(s.item(extractempty; store_input), v)

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
