"""
    DictExtractor{S} <: Extractor

extracts all items in `dict` and return them as a `Mill.ProductNode`.
If a key is missing in extracted dict, `nothing` is passed to the child extractors.

# Examples

```jldoctest
julia> e = DictExtractor(Dict(:a=>ExtractScalar(Float32, 2, 3),
                            :b=>CategoricalExtractor(1:5)))
Dict
  ├── a: Float32
  ╰── b: Categorical d = 6

julia> res1 = e(Dict("a"=>1, "b"=>1))
ProductNode  # 1 obs, 24 bytes
  ├── a: ArrayNode(1×1 Array with Union{Missing, Float32} elements)  # 1 obs, 53 bytes
  ╰── b: ArrayNode(6×1 MaybeHotMatrix with Union{Missing, Bool} elements)  # 1 obs, 77 bytes

julia> res1[:a]
1×1 ArrayNode{Matrix{Union{Missing, Float32}}, Nothing}:
 -3.0f0

julia> res1[:b]
6×1 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
  true
   ⋅
   ⋅
   ⋅
   ⋅
   ⋅

julia> res2 = e(Dict("a"=>0))
ProductNode  # 1 obs, 24 bytes
  ├── a: ArrayNode(1×1 Array with Union{Missing, Float32} elements)  # 1 obs, 53 bytes
  ╰── b: ArrayNode(6×1 MaybeHotMatrix with Union{Missing, Bool} elements)  # 1 obs, 77 bytes

julia> res2[:a]
1×1 ArrayNode{Matrix{Union{Missing, Float32}}, Nothing}:
 -6.0f0

julia> res2[:b]
6×1 ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int64, Union{Missing, Bool}}, Nothing}:
 missing
 missing
 missing
 missing
 missing
 missing
```
"""
struct DictExtractor{T <: NamedTuple} <: Extractor
    children::T
end

MacroTools.@forward DictExtractor.children Base.get, Base.haskey,
    Base.keys, Base.length, Base.isempty

Base.getindex(e::DictExtractor, k::Symbol) = e.children[k]

# @generated function (e::DictExtractor{<:NamedTuple{K}})(
#         v::Maybe{Union{Nothing, AbstractDict}}; store_input=false) where K
#     chs = if v == Missing || v == Nothing
#         [:(e.children.$k(v; store_input)) for k in K]
#     else
#         [:(e.children.$k(get(v, $(string(k)), missing); store_input)) for k in K]
#     end
#     quote
#         data = NamedTuple{$K}(tuple($(chs...)))
#         ProductNode(data, store_input ? [v] : nothing)
#     end
# end

@generated function (e::DictExtractor{<:NamedTuple{K}})(
        v::Maybe{AbstractDict}; store_input=Val(false)) where K
    chs = if v == Missing || v == Nothing
        [:(e.children.$k(v; store_input)) for k in K]
    else
        [:(e.children.$k(get(v, $(string(k)), missing); store_input)) for k in K]
    end
    quote
        data = NamedTuple{$K}(tuple($(chs...)))
        ProductNode(data, _metadata(v, store_input))
    end
end

@generated function (e::DictExtractor{<:NamedTuple{K}})(::Nothing) where K
    chs = [:(e.children.$k(nothing)) for k in K]
    quote
        data = NamedTuple{$K}(tuple($(chs...)))
        ProductNode(data)
    end
end

# @generated function (e::DictExtractor{<:NamedTuple{K}})(
#         v::AbstractDict; store_input=Val(false)) where K
#         chs = [:(haskey(v, $(string(k))) ? e.children.$k(v[$(string(k))]; store_input) : extract_missing(e.children.$k)) for k in K]
#     quote
#         data = NamedTuple{$K}(tuple($(chs...)))
#         ProductNode(data, _metadata(v, store_input))
#     end
# end
# @generated function extract_nothing(e::DictExtractor{<:NamedTuple{K}}) where K
#     chs = [:(extract_nothing(e.children.$k)) for k in K]
#     quote
#         data = NamedTuple{$K}(tuple($(chs...)))
#         ProductNode(data, _metadata(v, store_input))
#     end
# end
# @generated function extract_missing(e::DictExtractor{<:NamedTuple{K}}) where K
#     chs = [:(extract_missing(e.children.$k)) for k in K]
#     quote
#         data = NamedTuple{$K}(tuple($(chs...)))
#         ProductNode(data, _metadata(v, store_input))
#     end
# end

# @generated function (e::DictExtractor{<:NamedTuple{K}})(
#         v::Maybe{Union{Nothing, AbstractDict}}) where K
#     chs = if v == Missing || v == Nothing
#         [:(e.children.$k(v)) for k in K]
#     else
#         [:(e.children.$k(get(v, $(string(k)), missing))) for k in K]
#     end
#     quote
#         NamedTuple{$K}(tuple($(chs...))) |> ProductNode
#     end
# end
#
# @generated function extract_input(e::DictExtractor{<:NamedTuple{K}},
#         v::Maybe{Union{Nothing, AbstractDict}}) where K
#     chs = if v == Missing || v == Nothing
#         [:(extract_input(e.children.$k, v)) for k in K]
#     else
#         [:(extract_input(e.children.$k, get(v, $(string(k)), missing))) for k in K]
#     end
#     quote
#         data = NamedTuple{$K}(tuple($(chs...)))
#         ProductNode(data, [v])
#     end
# end

Base.hash(e::DictExtractor, h::UInt) = hash(e.children, h)
(e1::DictExtractor == e2::DictExtractor) = e1.children == e2.children
