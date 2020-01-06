module JsonGrinder
using Mill, JSON, Printf
using Mill: paddedprint, COLORS
include("schema.jl")
include("html_show_tools.jl")


using Mill: ArrayNode, BagNode, TreeNode, catobs
abstract type AbstractExtractor end;
include("extractors/extractarray.jl")
include("extractors/extractbranch.jl")
include("extractors/extractcategorical.jl")
include("extractors/extractscalar.jl")
include("extractors/extractstring.jl")
include("extractors/extractvector.jl")
include("extractors/extractonehot.jl")
include("extractors/multirepresentation.jl")

using Zygote, SparseArrays
Zygote.@adjoint function(A::Matrix * B::SparseMatrixCSC)
  	return A * B, Δ::AbstractMatrix->(Δ * B', nothing)
end


export ExtractScalar, ExtractCategorical, ExtractArray, ExtractBranch, ExtractOneHot, ExtractVector, MultipleRepresentation, ExtractString
export suggestextractor, schema, extractbatch, generate_html
end # module
