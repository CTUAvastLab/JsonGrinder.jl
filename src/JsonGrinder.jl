module JsonGrinder
using Mill, JSON, Printf, Flux
using Transducers
using HierarchicalUtils

using Mill: ArrayNode, BagNode, ProductNode, catobs
include("schema/schema.jl")
include("extractors/extractarray.jl")
include("extractors/extractdict.jl")
include("extractors/extractcategorical.jl")
include("extractors/extractscalar.jl")
include("extractors/extractstring.jl")
include("extractors/extractvector.jl")
include("extractors/extractonehot.jl")
include("extractors/extract_keyasfield.jl")
include("extractors/multirepresentation.jl")
include("html_show_tools.jl")

export ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractOneHot, ExtractVector, MultipleRepresentation, ExtractString
export suggestextractor, schema, extractbatch, generate_html

include("hierarchical_utils.jl")

Base.show(io::IO, ::T) where T <: Union{JSONEntry, AbstractExtractor} = show(io, Base.typename(T))
Base.show(io::IO, ::MIME"text/plain", n::Union{JSONEntry, AbstractExtractor}) = HierarchicalUtils.printtree(io, n; trav=false)
Base.getindex(n::Union{JSONEntry, AbstractExtractor}, i::AbstractString) = HierarchicalUtils.walk(n, i)

end # module
