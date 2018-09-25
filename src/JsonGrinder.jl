__precompile__(false)
module JsonGrinder
using Mill, JSON, Printf
using Mill: paddedprint, COLORS
include("schema.jl")

include("reflector.jl")
include("ngrams.jl")


export ExtractScalar, ExtractCategorical, ExtractArray, ExtractBranch
end # module
