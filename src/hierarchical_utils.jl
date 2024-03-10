import HierarchicalUtils: NodeType, LeafNode, InnerNode, children, nodeshow, nodecommshow

NodeType(::Type{<:Union{LeafEntry, Nothing}}) = LeafNode()
NodeType(::Type{<:AbstractJSONEntry}) = InnerNode()
# NodeType(::Type{<:AbstractExtractor}) = LeafNode()
# NodeType(::Type{<:Union{ExtractArray, ExtractDict, MultipleRepresentation, ExtractKeyAsField, AuxiliaryExtractor}}) = InnerNode()

children(n::ArrayEntry) = (n.items,)
# using vector of pairs because splatting to named tuple is not good for compiler
children(n::DictEntry) = n.children
# children(n::ExtractArray) = (n.item,)
# children(n::Pair) = (n.second,)
# children(n::MultipleRepresentation) = n.extractors
# children(e::ExtractKeyAsField) = (e.key, e.item)
# children(n::AuxiliaryExtractor) = (n.extractor,)
# children(n::ExtractDict) = (; Dict(Symbol(k)=>v for (k,v) in n.dict)...)

nodeshow(io::IO, ::Nothing) = print(io, "∅")
# nodeshow(io::IO, ::T) where T <: AbstractExtractor = print(io, "$(nameof(T))")
# nodeshow(io::IO, @nospecialize(::ExtractArray)) = print(io, "Array of")
# nodeshow(io::IO, @nospecialize(::ExtractDict)) = print(io, "Dict")
# nodeshow(io::IO, @nospecialize(n::ExtractCategorical)) = print(io, "Categorical d = $(n.n)")
# nodeshow(io::IO, ::ExtractScalar{T}) where {T} = print(io, "$(T)")
# nodeshow(io::IO, @nospecialize(::ExtractString)) = print(io, "String")
# nodeshow(io::IO, @nospecialize(n::ExtractVector)) = print(io, "FeatureVector with $(n.n) items")
# nodeshow(io::IO, @nospecialize(::MultipleRepresentation)) = print(io, "MultiRepresentation")
# nodeshow(io::IO, @nospecialize(::ExtractKeyAsField)) = print(io, "KeyAsField")
# nodeshow(io::IO, @nospecialize(::AuxiliaryExtractor)) = print(io, "Auxiliary extractor with")

nodecommshow(io::IO, @nospecialize(n::AbstractJSONEntry)) = print(io, " # updated = ", n.updated)
