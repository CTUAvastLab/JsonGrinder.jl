using Accessors: PropertyLens, IndexLens, ComposedOptic

import Mill: _pred_lens!

function Mill._pred_lens!(p::Function, n::T, l, result) where T <: Union{AbstractExtractor,
                                                                         JSONEntry}
    p(n) && push!(result, Accessors.opticcompose(l...))
    for k in fieldnames(T)
        _pred_lens!(p, getproperty(n, k), (l..., PropertyLens{k}()), result)
    end
end

# because of DictEntry
function Mill._pred_lens!(p::Function, n::Dict{Symbol}, l, result)
    p(n) && push!(result, Accessors.opticcompose(l...))
    for (k, v) in n
        _pred_lens!(p, v, (l..., IndexLens((k,))), result)
    end
end

# because of MultiEntry
function Mill._pred_lens!(p::Function, n::Vector{<:JSONEntry}, l, result)
    p(n) && push!(result, Accessors.opticcompose(l...))
    for (k, v) in enumerate(n)
        _pred_lens!(p, v, (l..., IndexLens((k,))), result)
    end
end

function Mill.code2lens(n::Union{AbstractExtractor, JSONEntry}, c::AbstractString)
    find_lens(n, n[c])
end
function Mill.lens2code(n::Union{AbstractExtractor, JSONEntry}, l)
    mapreduce(vcat, Accessors.getall(n, l)) do x
        HierarchicalUtils.find_traversal(n, x)
    end
end

# function schema_lens(model, lens::ComposedLens)
#     outerlens = schema_lens(model, lens.outer)
#     outerlens ∘ schema_lens(get(model, outerlens), lens.inner)
# end
# schema_lens(::ArrayEntry, ::PropertyLens{:data}) = @optic _.m
# schema_lens(::BagModel, ::PropertyLens{:data}) = @optic _.im
# schema_lens(::ProductModel, ::PropertyLens{:data}) = @optic _.ms
# schema_lens(::Union{NamedTuple, Tuple}, lens::IndexLens) = lens
# schema_lens(::Union{AbstractMillModel, NamedTuple, Tuple}, lens::IdentityLens) = lens
#
# function extractor_lens(ds, lens::ComposedLens)
#     outerlens = data_lens(ds, lens.outer)
#     outerlens ∘ data_lens(get(ds, outerlens), lens.inner)
# end
# extractor_lens(::ArrayNode, ::PropertyLens{:m}) = @optic _.data
# extractor_lens(::AbstractBagNode, ::PropertyLens{:im}) = @optic _.data
# extractor_lens(::AbstractProductNode, ::PropertyLens{:ms}) = @optic _.data
# extractor_lens(::Union{NamedTuple, Tuple}, lens::IndexLens) = lens
# extractor_lens(::Union{AbstractNode, NamedTuple, Tuple}, lens::IdentityLens) = lens
