module JsonGrinder

using Mill, JSON, Printf, Flux, OneHotArrays
using Accessors
using HierarchicalUtils

const FloatType = Float32

include("switches.jl")
include("schema/schema.jl")
include("extractors/extractors.jl")
include("html_show_tools.jl")
include("hierarchical_utils.jl")
include("util.jl")

export ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector, MultipleRepresentation, ExtractString, AuxiliaryExtractor, ExtractKeyAsField
export suggestextractor, schema, extractbatch, generate_html

Base.show(io::IO, ::T) where T <: Union{JSONEntry, AbstractExtractor} = print(io, nameof(T))
Base.show(io::IO, ::MIME"text/plain", @nospecialize(n::Union{JSONEntry, AbstractExtractor})) = 
    HierarchicalUtils.printtree(io, n; trav=false, htrunc=5, vtrunc=10, breakline=false)
Base.getindex(n::Union{JSONEntry, AbstractExtractor}, i::AbstractString) = HierarchicalUtils.walk(n, i)

end # module
