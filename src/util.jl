using Setfield: IdentityLens, PropertyLens, IndexLens, ComposedLens, Lens
import Mill: pred_lens, code2lens, lens2code, _pred_lens


function _pred_lens(n::T, p::Function) where T <: Union{AbstractExtractor, JSONEntry}
    res = vcat([map(l -> PropertyLens{k}() ∘ l, _pred_lens(getproperty(n, k), p))
                for k in fieldnames(T)]...)
    p(n) ? [IdentityLens(); res] : res
end
_pred_lens(n::Dict{Symbol, <:Any}, p::Function) = vcat([map(l -> IndexLens(tuple(k)) ∘ l, _pred_lens(v, p)) for (k, v) in n]...)

code2lens(n::Union{AbstractExtractor, JSONEntry}, c::AbstractString) = find_lens(n, n[c])
lens2code(n::Union{AbstractExtractor, JSONEntry}, l::Lens) = HierarchicalUtils.find_traversal(n, get(n, l))

# function schema_lens(model, lens::ComposedLens)
#     outerlens = schema_lens(model, lens.outer)
#     outerlens ∘ schema_lens(get(model, outerlens), lens.inner)
# end
# schema_lens(::ArrayEntry, ::PropertyLens{:data}) = @lens _.m
# schema_lens(::BagModel, ::PropertyLens{:data}) = @lens _.im
# schema_lens(::ProductModel, ::PropertyLens{:data}) = @lens _.ms
# schema_lens(::Union{NamedTuple, Tuple}, lens::IndexLens) = lens
# schema_lens(::Union{AbstractMillModel, NamedTuple, Tuple}, lens::IdentityLens) = lens
#
# function extractor_lens(ds, lens::ComposedLens)
#     outerlens = data_lens(ds, lens.outer)
#     outerlens ∘ data_lens(get(ds, outerlens), lens.inner)
# end
# extractor_lens(::ArrayNode, ::PropertyLens{:m}) = @lens _.data
# extractor_lens(::AbstractBagNode, ::PropertyLens{:im}) = @lens _.data
# extractor_lens(::AbstractProductNode, ::PropertyLens{:ms}) = @lens _.data
# extractor_lens(::Union{NamedTuple, Tuple}, lens::IndexLens) = lens
# extractor_lens(::Union{AbstractNode, NamedTuple, Tuple}, lens::IdentityLens) = lens
