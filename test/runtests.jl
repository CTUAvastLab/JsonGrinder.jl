using Test, Random

Random.seed!(0)

using JsonGrinder
using JsonGrinder: update!, InconsistentSchema

using Accessors
using Combinatorics
using Documenter
using HierarchicalUtils
using OneHotArrays
using JSON, JSON3
using Mill
using Mill: Maybe, Flux
using LinearAlgebra: I

# function buf_printtree(data; kwargs...)
#     buf = IOBuffer()
#     printtree(buf, data; kwargs...)
#     String(take!(buf))
# end

# const ≃ = isequal

# @testset "Doctests" begin
#     DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, quote
#         using JsonGrinder, Mill, OneHotArrays
#         # do not shorten prints in doctests
#         ENV["LINES"] = ENV["COLUMNS"] = typemax(Int)
#     end; recursive=true)
#     doctest(JsonGrinder)
# end

function common_extractor_tests(e::Extractor, v; test_stability=true)
    @test numobs(e(v)) == 1
    @test all(isnothing, Mill.metadata.(NodeIterator(e(v, store_input=Val(false)))))
    @test e(v, store_input=Val(true)).metadata == [v]
    @test dropmeta(e(v, store_input=Val(true))) == e(v)
    test_stability && @test_nowarn @inferred e(v)

    @test numobs(e(nothing)) == 0
    @test e(nothing).metadata |> isnothing
    @test dropmeta(e(nothing)) == e(nothing)
    test_stability && @test_nowarn @inferred e(nothing)

    if e isa LeafExtractor && !(e isa StableExtractor)
        @test_throws ErrorException e(missing)
    end
    e = stabilizeextractor(e)
    @test numobs(e(missing)) == 1
    @test e(missing, store_input=Val(false)).metadata |> isnothing
    @test isequal(e(missing, store_input=Val(true)).metadata, [missing])
    for x in [v, missing]
        @test isequal(dropmeta(e(x, store_input=Val(true))), e(x))
        @test all(n -> eltype(n.data) <: Union{Missing, T} where T, LeafIterator(e(x)))
        test_stability && @test_nowarn @inferred e(x)
    end
end

for test_f in readdir(".")
    (endswith(test_f, ".jl") && test_f ≠ "runtests.jl") || continue
    @testset verbose = true "$test_f" begin
        include(test_f)
    end
end
