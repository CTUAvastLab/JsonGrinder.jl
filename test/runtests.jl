using JsonGrinder
using Mill
using OneHotArrays
using Test
using Setfield
using InteractiveUtils
using Documenter
using Random

Random.seed!(0)

function buf_printtree(data; kwargs...)
    buf = IOBuffer()
    printtree(buf, data; kwargs...)
    String(take!(buf))
end

const ≃ = isequal

@testset "Doctests" begin
    DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, quote
        using JsonGrinder, Mill, OneHotArrays
        # do not shorten prints in doctests
        ENV["LINES"] = ENV["COLUMNS"] = typemax(Int)
    end; recursive=true)
    doctest(JsonGrinder)
end

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
    include("util.jl")
    include("json3.jl")
end
