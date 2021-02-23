using JsonGrinder
using Test
using Documenter

function buf_printtree(data; kwargs...)
    buf = IOBuffer()
	printtree(buf, data; kwargs...)
	String(take!(buf))
end

const ≃ = isequal

@testset "JsonGrinder.jl" begin

	# this must be first, because other tests include more imports which break string asserts on types
	@testset "Doctests" begin
    	DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, :(using JsonGrinder); recursive=true)
    	doctest(JsonGrinder)
	end

	include("extractors.jl")
	include("multirepresentation.jl")
	include("pipelinetest.jl")
	include("schema.jl")
	include("show_html.jl")
	include("hierarchical_utils_extractors.jl")
	include("hierarchical_utils_schema.jl")
	include("util.jl")

end
