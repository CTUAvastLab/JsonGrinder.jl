"""
    ArrayExtractor{T}

Convert array of values to a `Mill.BagNode` with items converted
by `item`. The entire array is assumed to be a single bag.

# Examples

```jldoctest
julia> ec = ArrayExtractor(CategoricalExtractor(2:4));

julia> ec([2, 3, 1, 4])
BagNode  # 1 obs, 88 bytes
  ╰── ArrayNode(4×4 MaybeHotMatrix with Union{Missing, Bool} elements)  # 4 obs, 92 bytes

julia> ans.data
4×4 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
  true    ⋅      ⋅      ⋅  
   ⋅     true    ⋅      ⋅
   ⋅      ⋅      ⋅     true
   ⋅      ⋅     true    ⋅

julia> es = ArrayExtractor(ExtractScalar());

julia> es([2,3,4])
BagNode  # 1 obs, 80 bytes
  ╰── ArrayNode(1×3 Array with Union{Missing, Float32} elements)  # 3 obs, 63 bytes

julia> es([2,3,4]).data
1×3 ArrayNode{Matrix{Union{Missing, Float32}}, Nothing}:
 2.0f0  3.0f0  4.0f0
```
"""
struct ArrayExtractor{T} <: Extractor
    items::T
end

# function (e::ArrayExtractor)(v::AbstractVector{T}; store_input=false) where T
#     # isempty(v) && return e(missing; store_input)
#     isempty(v) && return BagNode(e.items(nothing; store_input), [0:-1], store_input ? T[] : nothing)
#     data = reduce(catobs, e.items.(v; store_input))
#     BagNode(data, [1:length(v)], store_input ? [v] : nothing)
# end
# function (e::ArrayExtractor)(v::Missing; store_input=false)
#     BagNode(e.items(nothing; store_input), [0:-1], store_input ? [v] : nothing)
# end
# function (e::ArrayExtractor)(v::Nothing; store_input=false)
#     BagNode(e.items(nothing; store_input), UnitRange{Int}[], store_input ? [v] : nothing)
# end

function (e::ArrayExtractor)(v::AbstractVector; store_input=Val(false))
    isempty(v) && return BagNode(e.items(nothing), [0:-1], _metadata(v, store_input))
    data = reduce(catobs, [e.items(x; store_input) for x in v])
    BagNode(data, [1:length(v)], _metadata(v, store_input))
end
function (e::ArrayExtractor)(v::Missing; store_input=Val(false))
    BagNode(e.items(nothing), [0:-1], _metadata(v, store_input))
end
function (e::ArrayExtractor)(::Nothing)
    BagNode(e.items(nothing), UnitRange{Int}[])
end

# function (e::ArrayExtractor)(v::AbstractVector; store_input=Val(false))
#     isempty(v) && return BagNode(extract_nothing(e.items), [0:-1], _metadata(v, store_input))
#     data = reduce(catobs, e.items.(v; store_input))
#     BagNode(data, [1:length(v)], _metadata(v, store_input))
# end
# function (e::ArrayExtractor)(v::AbstractVector)
#     println("x")
#     isempty(v) && return BagNode(extract_nothing(e.items), [0:-1])
#     # data = reduce(catobs, e.items.(v))
#     data = reduce(catobs, [e.items(x) for x in v])
#     BagNode(data, [1:length(v)])
# end
# function (e::ArrayExtractor)(v::AbstractVector)
#     print("3")
#     isempty(v) && return BagNode(extract_nothing(e.items), [0:-1])
#     data = reduce(catobs, [e.items(x) for x in v])
#     BagNode(data, [1:length(v)])
# end
# extract_missing(e::ArrayExtractor) = BagNode(extract_nothing(e.items), [0:-1])
# extract_nothing(e::ArrayExtractor) = BagNode(extract_nothing(e.items), UnitRange{Int}[])

# function (e::ArrayExtractor)(v::AbstractVector)
#     isempty(v) && return e(missing)
#     data = reduce(catobs, map(e.items, v))
#     BagNode(data, [1:length(v)])
# end
# (e::ArrayExtractor)(::Missing) = BagNode(e.items(nothing), [0:-1])
# (e::ArrayExtractor)(::Nothing) = BagNode(e.items(nothing), UnitRange{Int}[])
#
# function extract_input(e::ArrayExtractor, v::AbstractVector)
#     isempty(v) && return extract_input(e, missing)
#     data = reduce(catobs, map(x -> extract_input(e.items, x), v))
#     BagNode(data, [1:length(v)], [v])
# end
# extract_input(e::ArrayExtractor, ::Missing) = BagNode(e.items(nothing), [0:-1], [nothing])
# extract_input(e::ArrayExtractor, ::Nothing) = BagNode(e.items(nothing), UnitRange{Int}[], [nothing])


Base.hash(e::ArrayExtractor, h::UInt) = hash(e.items, h)
(e1::ArrayExtractor == e2::ArrayExtractor) = e1.items == e2.items
