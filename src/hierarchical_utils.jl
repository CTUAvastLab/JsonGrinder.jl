import HierarchicalUtils: NodeType, childrenfields, children, InnerNode, SingletonNode, LeafNode, printtree, noderepr

# for schema structures
NodeType(::Type{Entry}) = LeafNode()
NodeType(::Type{ArrayEntry}) = SingletonNode()
NodeType(::Type{DictEntry}) = InnerNode()

noderepr(n::Entry) = "[Scalar - $(join(sort(string.(types(n))), ","))], $(length(keys(n.counts))) unique values, updated = $(n.updated)"
noderepr(n::ArrayEntry) = "[" * (isnothing(n.items) ? "Empty " : "") * "List] (updated = $(n.updated))"
noderepr(n::DictEntry) = "[" * (isnothing(n.childs) ? "Empty " : "") * "Dict] (updated = $(n.updated))"

childrenfields(::Type{ArrayEntry}) = (:items,)
childrenfields(::Type{DictEntry}) = (:childs,)

children(n::ArrayEntry) = (n.items,)
children(n::DictEntry) = (; n.childs...)

# for extractor structures
NodeType(::Type{T}) where T <: ExtractArray = SingletonNode()
NodeType(::Type{T}) where T <: ExtractBranch = InnerNode()
NodeType(::Type{T}) where T <: ExtractCategorical = LeafNode()
NodeType(::Type{T}) where T <: ExtractOneHot = LeafNode()
NodeType(::Type{T}) where T <: ExtractScalar = LeafNode()
NodeType(::Type{T}) where T <: ExtractString = LeafNode()
NodeType(::Type{T}) where T <: ExtractVector = LeafNode()
NodeType(::Type{T}) where T <: MultipleRepresentation = InnerNode()

noderepr(n::ExtractArray) = "Array of"
noderepr(n::ExtractBranch) = "Dict"
noderepr(n::ExtractCategorical) = "Categorical d = $(n.n)"
noderepr(n::ExtractOneHot) = "OneHot d = $(n.n)"
noderepr(n::ExtractScalar) = "$(n.datatype)"
noderepr(n::ExtractString) = "$(n.datatype)"
noderepr(n::ExtractVector) = "FeatureVector with $(n.n) items"
noderepr(n::MultipleRepresentation) = "MultiRepresentation"

childrenfields(::Type{T}) where T <: ExtractArray = (:item,)
childrenfields(::Type{T}) where T <: ExtractBranch = (:vec, :other)
childrenfields(::Type{T}) where T <: MultipleRepresentation = (:extractors,)

children(n::ExtractArray) = (n.item,)
children(n::ExtractBranch) = (; Dict(Symbol(k)=>v for (k,v) in merge(filter(!isnothing, [n.vec, n.other])...))...)
children(n::MultipleRepresentation) = n.extractors

# Base.getindex(x::AbstractNode, i::Int) = x[i:i]
#
# # by šimon from Mill
# NodeType(::Type{<:Union{ArrayNode, ArrayModel, BagNode{Missing}}}) = LeafNode()
# NodeType(::Type{<:AbstractNode}) = InnerNode()
# NodeType(::Type{<:AbstractBagNode}) = SingletonNode()
# NodeType(::Type{<:BagModel}) = SingletonNode()
# NodeType(::Type{<:MillModel}) = InnerNode()
#
# noderepr(n::ArrayNode) = "ArrayNode$(size(n.data))"
# noderepr(n::ArrayModel) = "ArrayModel($(n.m))"
# noderepr(n::BagNode) = "BagNode with $(length(n.bags)) bag(s)"
# noderepr(n::BagModel) = "BagModel ↦ $(repr("text/plain", n.a)) ↦ $(repr("text/plain", n.bm))"
# noderepr(n::WeightedBagNode) = "WeightedNode with $(length(n.bags)) bag(s) and weights Σw = $(sum(n.weights))"
# noderepr(n::AbstractTreeNode) = "TreeNode"
# noderepr(n::ProductModel) = "ProductModel ↦ $(noderepr(n.m))"
#
# childrenfield(::Type{<:Union{AbstractTreeNode, AbstractBagNode}}) = :data
# childrenfield(::Type{BagModel}) = :im
# childrenfield(::Type{ProductModel}) = :ms
#
# children(n::AbstractBagNode) = (n.data,)
# children(n::BagModel) = (n.im,)
# children(n::TreeNode) = n.data
# children(n::ProductModel) = n.ms
#
# childrenstring(n::TreeNode{<:NamedTuple}) = ["$k: " for k in keys(n.data)]
# childrenstring(n::ProductModel{<:NamedTuple}) = ["$k: " for k in keys(n.ms)]
