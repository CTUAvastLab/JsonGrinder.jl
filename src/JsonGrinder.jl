module JsonGrinder
using Mill, JSON, Printf, Flux
using HierarchicalUtils
import HierarchicalUtils: NodeType, children, InnerNode, LeafNode, printtree, noderepr

using Mill: ArrayNode, BagNode, ProductNode, catobs, NGramMatrix

const FloatType = Float32

include("schema/schema.jl")
include("extractors/extractors.jl")
include("html_show_tools.jl")
include("hierarchical_utils.jl")
include("util.jl")

export ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractOneHot, ExtractVector, MultipleRepresentation, ExtractString, AuxiliaryExtractor, ExtractKeyAsField
export suggestextractor, schema, extractbatch, generate_html

Base.show(io::IO, ::T) where T <: Union{JSONEntry, AbstractExtractor} = show(io, Base.typename(T))
Base.show(io::IO, ::MIME"text/plain", n::Union{JSONEntry, AbstractExtractor}) = HierarchicalUtils.printtree(io, n; trav=false, htrunc=3, vtrunc=20)
Base.getindex(n::Union{JSONEntry, AbstractExtractor}, i::AbstractString) = HierarchicalUtils.walk(n, i)

end # module
