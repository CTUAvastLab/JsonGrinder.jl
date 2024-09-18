"""
    DictExtractor{S} <: Extractor

Extracts all items in a `Dict` and returns them as a `Mill.ProductNode`.

# Examples
```jldoctest
julia> e = (a=ScalarExtractor(), b=CategoricalExtractor(1:5)) |> DictExtractor
DictExtractor
  ├── a: ScalarExtractor(c=0.0, s=1.0)
  ╰── b: CategoricalExtractor(n=6)

julia> e(Dict("a" => 1, "b" => 1))
ProductNode  1 obs, 24 bytes
  ├── a: ArrayNode(1×1 Array with Float32 elements)  1 obs, 52 bytes
  ╰── b: ArrayNode(6×1 OneHotArray with Bool elements)  1 obs, 76 bytes
```
"""
struct DictExtractor{T <: NamedTuple} <: Extractor
    children::T
end

MacroTools.@forward DictExtractor.children Base.get, Base.haskey,
    Base.keys, Base.length, Base.isempty

Base.getindex(e::DictExtractor, k::Symbol) = e.children[k]

@generated function (e::DictExtractor{<:NamedTuple{K}})(
        v::Maybe{AbstractDict}; store_input=Val(false)) where K
    chs = if v == Missing || v == Nothing
        [:(e.children.$k(v; store_input)) for k in K]
    else
        [:(@try_catch_dict(
            $(QuoteNode(k)),
            e.children.$k(get(v, $(string(k)), missing); store_input)
        )) for k in K]
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

@generated function extract(e::DictExtractor{<:NamedTuple{K}}, V;
                            store_input=Val(false)) where K
    chs = map(K) do k
        quote
            ch = Vector{Any}(undef, length(V))
            for (i, v) in enumerate(V)
                if v isa AbstractDict
                    ch[i] = get(v, $(string(k)), missing)
                elseif ismissing(v)
                    ch[i] = missing
                else
                    throw(IncompatibleExtractor())
                end
            end
            @try_catch_dict $(QuoteNode(k)) extract(e.children.$k, ch; store_input)
        end
    end
    quote
        data = NamedTuple{$K}(tuple($(chs...)))
        ProductNode(data, _metadata_batch(V, store_input))
    end
end

Base.hash(e::DictExtractor, h::UInt) = hash(e.children, h)
(e1::DictExtractor == e2::DictExtractor) = e1.children == e2.children
