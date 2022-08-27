import HierarchicalUtils: NodeType, children, InnerNode, LeafNode, printtree, nodeshow, nodecommshow

# for schema structures
NodeType(::Type{<:Union{Nothing, Entry}}) = LeafNode()  # because sometimes we have empty array extractor
NodeType(::Type{Pair{Symbol,Any}}) = InnerNode()  # because sometimes we have empty array extractor
NodeType(::Type{<:Union{ArrayEntry, DictEntry, MultiEntry}}) = InnerNode()

nodeshow(io::IO, ::Nothing) = print(io, "Nothing")
nodeshow(io::IO, n::Entry) = print(io, "[Scalar - $(join(sort(string.(types(n))), ","))], $(length(keys(n.counts))) unique values")
nodeshow(io::IO, @nospecialize(n::ArrayEntry)) = print(io, "[" * (isnothing(n.items) ? "Empty " : "") * "List]")
nodeshow(io::IO, @nospecialize(n::DictEntry)) = print(io, "[" * (isnothing(n.childs) ? "Empty " : "") * "Dict]")
nodeshow(io::IO, @nospecialize(n::MultiEntry)) = print(io, "[" * (isempty(n.childs) ? "Empty " : "") * "MultiEntry]")

nodecommshow(io::IO, @nospecialize(n::JSONEntry)) = print(io, " # updated = $(n.updated)")

children(n::ArrayEntry) = (n.items,)
# using vector of pairs because splatting to named tuple is not good for compiler
children(n::DictEntry) = collect(n.childs)
children(n::MultiEntry) = [Symbol(k) => v for (k,v) in enumerate(n.childs)]

# for extractor structures
# default extractor
NodeType(::Type{<:AbstractExtractor}) = LeafNode()
NodeType(::Type{<:Union{ExtractArray, ExtractDict, MultipleRepresentation, ExtractKeyAsField, AuxiliaryExtractor}}) = InnerNode()

nodeshow(io::IO, ::T) where T <: AbstractExtractor = print(io, "$(nameof(T))")
nodeshow(io::IO, @nospecialize(::ExtractArray)) = print(io, "Array of")
nodeshow(io::IO, @nospecialize(::ExtractDict)) = print(io, "Dict")
nodeshow(io::IO, @nospecialize(n::ExtractCategorical)) = print(io, "Categorical d = $(n.n)")
nodeshow(io::IO, ::ExtractScalar{T}) where {T} = print(io, "$(T)")
nodeshow(io::IO, @nospecialize(::ExtractString)) = print(io, "String")
nodeshow(io::IO, @nospecialize(n::ExtractVector)) = print(io, "FeatureVector with $(n.n) items")
nodeshow(io::IO, @nospecialize(::MultipleRepresentation)) = print(io, "MultiRepresentation")
nodeshow(io::IO, @nospecialize(::ExtractKeyAsField)) = print(io, "KeyAsField")
nodeshow(io::IO, @nospecialize(::AuxiliaryExtractor)) = print(io, "Auxiliary extractor with")

children(n::ExtractArray) = (n.item,)
children(n::Pair) = (n.second,)
children(n::MultipleRepresentation) = n.extractors
children(e::ExtractKeyAsField) = (e.key, e.item)
children(n::AuxiliaryExtractor) = (n.extractor,)
children(n::ExtractDict) = (; Dict(Symbol(k)=>v for (k,v) in n.dict)...)
