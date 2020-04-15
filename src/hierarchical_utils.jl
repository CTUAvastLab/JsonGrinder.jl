import HierarchicalUtils: NodeType, childrenfields, children, InnerNode, SingletonNode, LeafNode, printtree, noderepr

# for schema structures
NodeType(::Type{Nothing}) = LeafNode()  # because sometimes we have empty array extractor
NodeType(::Type{Entry}) = LeafNode()
NodeType(::Type{ArrayEntry}) = SingletonNode()
NodeType(::Type{DictEntry}) = InnerNode()

noderepr(n::Nothing) = "Nothing"
noderepr(n::Entry) = "[Scalar - $(join(sort(string.(types(n))), ","))], $(length(keys(n.counts))) unique values, updated = $(n.updated)"
noderepr(n::ArrayEntry) = "[" * (isnothing(n.items) ? "Empty " : "") * "List] (updated = $(n.updated))"
noderepr(n::DictEntry) = "[" * (isnothing(n.childs) ? "Empty " : "") * "Dict] (updated = $(n.updated))"

childrenfields(::Type{ArrayEntry}) = (:items,)
childrenfields(::Type{DictEntry}) = (:childs,)

children(n::ArrayEntry) = (n.items,)
children(n::DictEntry) = (; n.childs...)

# for extractor structures
NodeType(::Type{T}) where T <: ExtractArray = SingletonNode()
NodeType(::Type{T}) where T <: ExtractDict = InnerNode()
NodeType(::Type{T}) where T <: ExtractCategorical = LeafNode()
NodeType(::Type{T}) where T <: ExtractOneHot = LeafNode()
NodeType(::Type{T}) where T <: ExtractScalar = LeafNode()
NodeType(::Type{T}) where T <: ExtractString = LeafNode()
NodeType(::Type{T}) where T <: ExtractVector = LeafNode()
NodeType(::Type{T}) where T <: MultipleRepresentation = InnerNode()

noderepr(n::ExtractArray) = "Array of"
noderepr(n::ExtractDict) = "Dict"
noderepr(n::ExtractCategorical) = "Categorical d = $(n.n)"
noderepr(n::ExtractOneHot) = "OneHot d = $(n.n)"
noderepr(n::ExtractScalar) = "$(n.datatype)"
noderepr(n::ExtractString) = "$(n.datatype)"
noderepr(n::ExtractVector) = "FeatureVector with $(n.n) items"
noderepr(n::MultipleRepresentation) = "MultiRepresentation"

childrenfields(::Type{T}) where T <: ExtractArray = (:item,)
childrenfields(::Type{T}) where T <: ExtractDict = (:vec, :other)
childrenfields(::Type{T}) where T <: MultipleRepresentation = (:extractors,)

children(n::ExtractArray) = (n.item,)
children(n::ExtractDict) = (; Dict(Symbol(k)=>v for (k,v) in merge(filter(!isnothing, [n.vec, n.other])...))...)
children(n::MultipleRepresentation) = n.extractors