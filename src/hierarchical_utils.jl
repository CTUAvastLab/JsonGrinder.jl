import HierarchicalUtils: NodeType, children, InnerNode, LeafNode, printtree, noderepr

# for schema structures
NodeType(::Type{Nothing}) = LeafNode()  # because sometimes we have empty array extractor
NodeType(::Type{ArrayEntry}) = InnerNode()
NodeType(::Type{DictEntry}) = InnerNode()
NodeType(::Type{MultiEntry}) where {T<:MultiEntry} = InnerNode()
NodeType(::Type{T}) where {T<:Entry} = LeafNode()

noderepr(n::Nothing) = "Nothing"
noderepr(n::Entry) = "[Scalar - $(join(sort(string.(types(n))), ","))], $(length(keys(n.counts))) unique values, updated = $(n.updated)"
noderepr(n::ArrayEntry) = "[" * (isnothing(n.items) ? "Empty " : "") * "List] (updated = $(n.updated))"
noderepr(n::DictEntry) = "[" * (isnothing(n.childs) ? "Empty " : "") * "Dict] (updated = $(n.updated))"
noderepr(n::MultiEntry) = "[" * (isempty(n.childs) ? "Empty " : "") * "MultiEntry] (updated = $(n.updated))"

children(n::ArrayEntry) = (n.items,)
children(n::DictEntry) = (; n.childs...)
children(n::MultiEntry) = (; Dict( Symbol(k) => v for (k,v) in enumerate(n.childs))...)

# for extractor structures
# default extractor
NodeType(::Type{T}) where T <: AbstractExtractor = LeafNode()
NodeType(::Type{T}) where T <: ExtractArray = InnerNode()
NodeType(::Type{T}) where T <: ExtractDict = InnerNode()
NodeType(::Type{T}) where T <: MultipleRepresentation = InnerNode()
NodeType(::Type{T}) where {T<: ExtractKeyAsField} = InnerNode()

noderepr(::T) where T <: AbstractExtractor = "$(Base.nameof(T))"
noderepr(n::ExtractArray) = "Array of"
noderepr(n::ExtractDict) = "Dict"
noderepr(n::ExtractCategorical) = "Categorical d = $(n.n)"
noderepr(n::ExtractOneHot) = "OneHot d = $(n.n)"
noderepr(n::ExtractScalar) = "$(n.datatype)"
noderepr(n::ExtractString) = "$(n.datatype)"
noderepr(n::ExtractVector) = "FeatureVector with $(n.n) items"
noderepr(n::MultipleRepresentation) = "MultiRepresentation"
noderepr(e::ExtractKeyAsField) = "KeyAsField"

children(n::ExtractArray) = (n.item,)
children(n::ExtractDict) = (; Dict(Symbol(k)=>v for (k,v) in merge(filter(!isnothing, [n.vec, n.other])...))...)
children(n::MultipleRepresentation) = n.extractors
children(e::ExtractKeyAsField) = (e.key, e.item)
