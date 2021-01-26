struct ExtractEmpty end

"""
    extractempty

A singleton of type [`ExtractEmpty`](@ref) is used to signal
downstream extractors that they should extract an Empty Array
"""
const extractempty = ExtractEmpty()

include("auxiliary.jl")
include("extractarray.jl")
include("extractdict.jl")
include("extractcategorical.jl")
include("extractscalar.jl")
include("extractstring.jl")
include("extractvector.jl")
include("extractonehot.jl")
include("extract_keyasfield.jl")
include("multirepresentation.jl")
