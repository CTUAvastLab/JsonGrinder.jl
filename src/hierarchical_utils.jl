using HierarchicalUtils
import HierarchicalUtils: NodeType, childrenfields, children, childrenstring, InnerNode, SingletonNode, LeafNode, printtree

# for schema structures
NodeType(::Type{Entry}) = LeafNode()
NodeType(::Type{ArrayEntry}) = SingletonNode()
NodeType(::Type{DictEntry}) = InnerNode()

noderepr(n::Entry) = "[Scalar - $(types(n))], $(length(keys(e.counts))) unique values, updated = $(e.updated)"
noderepr(n::ArrayEntry) = "[" * (isnothing(n.items) ? "Empty " : "") * "List] (updated = $(n.updated))"
noderepr(n::DictEntry) = "[" * (isnothing(n.items) ? "Empty " : "") * "Dict] (updated = $(n.updated))"


methods(noderepr)
NodeType(Entry)
NodeType(ArrayEntry)
NodeType(DictEntry)



childrenfields(::Type{ArrayEntry}) = (:items,)
childrenfields(::Type{DictEntry}) = (:childs,)

children(n::ArrayEntry) = (n.items,)
children(n::DictEntry) = n.children

childrenstring(n::DictEntry) = ["$k: " for k in keys(n.children)]
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
