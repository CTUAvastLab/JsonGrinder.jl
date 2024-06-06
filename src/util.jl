function Mill._pred_lens!(p::Function, n::T, l, result) where T <: Union{Extractor,
                                                                         Schema}
    p(n) && push!(result, Accessors.opticcompose(l...))
    for k in fieldnames(T)
        Mill._pred_lens!(p, getproperty(n, k), (l..., PropertyLens{k}()), result)
    end
end

function Mill._pred_lens!(p::Function, n::DictEntry, l, result)
    p(n) && push!(result, Accessors.opticcompose(l...))
    p(n.updated) && push!(result, Accessors.opticcompose(l..., PropertyLens{:updated}()))
    p(n.children) && push!(result, Accessors.opticcompose(l..., PropertyLens{:children}()))
    for (k, v) in n.children
        Mill._pred_lens!(p, v, (l..., PropertyLens{:children}(), IndexLens((k,))), result)
    end
end

function Mill._pred_lens!(p::Function, n::ArrayEntry, l, result)
    p(n) && push!(result, Accessors.opticcompose(l...))
    p(n.updated) && push!(result, Accessors.opticcompose(l..., PropertyLens{:updated}()))
    if !isnothing(n.items)
        Mill._pred_lens!(p, n.items, (l..., PropertyLens{:items}()), result)
    end
end

Mill.code2lens(n::Union{Extractor, Schema}, c::AbstractString) = find_lens(n, n[c])

function Mill.lens2code(n::Union{Extractor, Schema}, l)
    mapreduce(vcat, Accessors.getall(n, l)) do x
        HierarchicalUtils.find_traversal(n, x)
    end
end
