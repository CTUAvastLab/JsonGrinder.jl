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
ProductNode  1 obs
  ├── a: ArrayNode(1×1 Array with Float32 elements)  1 obs
  ╰── b: ArrayNode(6×1 OneHotArray with Bool elements)  1 obs
```
"""
struct DictExtractor{T <: NamedTuple} <: Extractor
    children::T
end

MacroTools.@forward DictExtractor.children Base.get, Base.haskey,
    Base.keys, Base.length, Base.isempty

Base.getindex(e::DictExtractor, k::Symbol) = e.children[k]

@generated function (e::DictExtractor{<:NamedTuple{K}})(
        v::Maybe{AbstractDict{T}}; store_input=Val(false)) where {K, T <: Union{Symbol, String}}
    chs = if v == Missing
        [:(e.children.$k(missing; store_input)) for k in K]
    else
        map(K) do k
            quote
                @try_catch_dict(
                    $(QuoteNode(k)),
                    e.children.$k(get(v, $(QuoteNode(T(k))), missing); store_input)
                )
            end
        end
    end
    quote
        data = NamedTuple{$K}(tuple($(chs...)))
        ProductNode(data, _metadata(v, store_input))
    end
end

(e::DictExtractor)(::Nothing; store_input=Val(false)) = _error_null_values()

@generated function (e::DictExtractor{<:NamedTuple{K}})(::ExtractEmpty) where K
    chs = [:(e.children.$k(extractempty)) for k in K]
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
                    ch[i] = get(v, keytype(v)($(QuoteNode(k))), missing)
                elseif ismissing(v)
                    ch[i] = missing
                elseif isnothing(v)
                    _error_null_values()
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
