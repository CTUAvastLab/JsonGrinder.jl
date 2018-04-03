module JsonGrinder
using Mill
using JSON
include("schema.jl")

include("reflector.jl")
include("ngrams.jl")


export ExtractScalar, ExtractCategorical, ExtractArray, ExtractBranch
end # module
