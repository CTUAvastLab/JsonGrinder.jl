import HierarchicalUtils: NodeType, children, InnerNode, LeafNode, printtree, noderepr

# for schema structures
NodeType(::Type{<:Union{Nothing, Entry}}) = LeafNode()  # because sometimes we have empty array extractor
NodeType(::Type{Pair{Symbol,Any}}) = InnerNode()  # because sometimes we have empty array extractor
NodeType(::Type{<:Union{ArrayEntry, DictEntry, MultiEntry}}) = InnerNode()

noderepr(n::Nothing) = "Nothing"
noderepr(n::Entry) = "[Scalar - $(join(sort(string.(types(n))), ","))], $(length(keys(n.counts))) unique values, updated = $(n.updated)"
noderepr(n::ArrayEntry) = "[" * (isnothing(n.items) ? "Empty " : "") * "List] (updated = $(n.updated))"
noderepr(n::DictEntry) = "[" * (isnothing(n.childs) ? "Empty " : "") * "Dict] (updated = $(n.updated))"
noderepr(n::MultiEntry) = "[" * (isempty(n.childs) ? "Empty " : "") * "MultiEntry] (updated = $(n.updated))"

children(n::ArrayEntry) = (n.items,)
# using vector of pairs because splatting to named tuple is not good for compiler
children(n::DictEntry) = collect(n.childs)
children(n::MultiEntry) = [Symbol(k) => v for (k,v) in enumerate(n.childs)]

# for extractor structures
# default extractor
NodeType(::Type{<:AbstractExtractor}) = LeafNode()
NodeType(::Type{<:Union{ExtractArray, ExtractDict, MultipleRepresentation, ExtractKeyAsField, AuxiliaryExtractor}}) = InnerNode()

noderepr(::T) where T <: AbstractExtractor = "$(Base.nameof(T))"
noderepr(n::ExtractArray) = "Array of"
noderepr(n::ExtractDict) = "Dict"
noderepr(n::ExtractCategorical) = "Categorical d = $(n.n)"
noderepr(n::ExtractScalar{T}) where {T} = "$(T)"
noderepr(n::ExtractString) = "String"
noderepr(n::ExtractVector) = "FeatureVector with $(n.n) items"
noderepr(n::MultipleRepresentation) = "MultiRepresentation"
noderepr(e::ExtractKeyAsField) = "KeyAsField"
noderepr(n::AuxiliaryExtractor) = "Auxiliary extractor with"

children(n::ExtractArray) = (n.item,)
children(n::Pair) = (n.second,)
children(n::MultipleRepresentation) = n.extractors
children(e::ExtractKeyAsField) = (e.key, e.item)
children(n::AuxiliaryExtractor) = (n.extractor,)
children(n::ExtractDict) = (; Dict(Symbol(k)=>v for (k,v) in n.dict)...)
