using JsonGrinder
using Test
using Documenter
using Random

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

	# now we have some random things in tests, fixing the seed
	Random.seed!(0)

	@testset "Extractors" begin
		include("extractors.jl")
		include("multirepresentation.jl")
	end
	@testset "Pipeline" begin
		include("pipelinetest.jl")
	end
	@testset "Schema" begin
		include("schema.jl")
	end
	@testset "HierarchicalUtils" begin
		include("hierarchical_utils_extractors.jl")
		include("hierarchical_utils_schema.jl")
	end
	include("show_html.jl")
	include("util.jl")
	include("json3.jl")

end
