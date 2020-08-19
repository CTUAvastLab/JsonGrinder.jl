using JsonGrinder
using Test

function buf_printtree(data; kwargs...)
    buf = IOBuffer()
	printtree(buf, data; kwargs...)
	String(take!(buf))
end

include("extractors.jl")
include("multirepresentation.jl")
include("pipelinetest.jl")
include("schema.jl")
include("show_html.jl")
include("hierarchical_utils_extractors.jl")
include("hierarchical_utils_schema.jl")
