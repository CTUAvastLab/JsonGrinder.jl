module JsonGrinder
using Mill
using JSON
import Mill.paddedprint
include("schema.jl")

include("reflector.jl")
include("ngrams.jl")


export ExtractScalar, ExtractCategorical, ExtractArray, ExtractBranch
end # module
