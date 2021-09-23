using JsonGrinder
using Test

function buf_printtree(data; kwargs...)
    buf = IOBuffer()
	printtree(buf, data; kwargs...)
	String(take!(buf))
end

const ≃ = isequal

@testset "JsonGrinder.jl" begin

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

end
