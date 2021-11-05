"""
    struct ExtractEmpty end

Concrete type to dispatch on for extraction of empty samples.
"""
struct ExtractEmpty end

"""
    extractempty

A singleton of type [`ExtractEmpty`](@ref) is used to signal
downstream extractors that they should extract an empty sample.
"""
const extractempty = ExtractEmpty()

const MissingOrNothing = Union{Missing, Nothing}
const HierarchicType = Union{AbstractDict, AbstractVector, StringOrNumber, MissingOrNothing, ExtractEmpty}

_make_array_node(x, v, store_input) = store_input ? ArrayNode(x, v) : ArrayNode(x)
_make_bag_node(x, bags, v, store_input) = store_input ? BagNode(x, bags, v) : BagNode(x, bags)

"""
returns empty bag of 0 observations
"""
make_empty_bag(x, v) = BagNode(x, Mill.AlignedBags(Vector{UnitRange{Int64}}()))

include("auxiliary.jl")
include("extractarray.jl")
include("extractdict.jl")
include("extractcategorical.jl")
include("extractscalar.jl")
include("extractstring.jl")
include("extractvector.jl")
include("extract_keyasfield.jl")
include("multirepresentation.jl")
