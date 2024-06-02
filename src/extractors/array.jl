"""
    ArrayExtractor{T}

Extracts all items in an `Array` and returns them as a `Mill.BagNode`.

# Examples
```jldoctest
julia> e = ArrayExtractor(CategoricalExtractor(2:4))
ArrayExtractor
  ╰── CategoricalExtractor(n=4)

julia> e([2, 3, 1, 4])
BagNode  1 obs, 88 bytes
  ╰── ArrayNode(4×4 OneHotArray with Bool elements)  4 obs, 88 bytes
```
"""
struct ArrayExtractor{T} <: Extractor
    items::T
end

function (e::ArrayExtractor)(v::AbstractVector; store_input=Val(false))
    isempty(v) && return BagNode(e.items(nothing), [0:-1], _metadata(v, store_input))
    data = reduce(catobs, [@try_catch_array e.items(x; store_input) for x in v])
    BagNode(data, [1:length(v)], _metadata(v, store_input))
end
function (e::ArrayExtractor)(v::Missing; store_input=Val(false))
    BagNode(e.items(nothing), [0:-1], _metadata(v, store_input))
end
function (e::ArrayExtractor)(::Nothing)
    BagNode(e.items(nothing), UnitRange{Int}[])
end

function extract(e::ArrayExtractor, V::AbstractVector; store_input=Val(false))
    s = 0
    ls = Vector{Int}(undef, length(V))
    for (i, v) in enumerate(V)
        if ismissing(v)
            ls[i] = 0
        elseif v isa AbstractVector
            s += length(v)
            ls[i] = length(v)
        else
            throw(IncompatibleExtractor())
        end
    end

    chs = Vector{Any}(undef, s)
    i = 1
    for v in V
        if !ismissing(v)
            chs[i:i+length(v)-1] = v
            i += length(v)
        end
    end

    data = @try_catch_array extract(e.items, chs; store_input)
    BagNode(data, length2bags(ls), _metadata_batch(V, store_input))
end

Base.hash(e::ArrayExtractor, h::UInt) = hash(e.items, h)
(e1::ArrayExtractor == e2::ArrayExtractor) = e1.items == e2.items
