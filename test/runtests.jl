using JsonGrinder
using Test
using Documenter

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

@testset "Doctests" begin
    DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, :(using JsonGrinder); recursive=true)
    doctest(JsonGrinder)
end
