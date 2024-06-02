using Test, Random

Random.seed!(0)

using Accessors
using Combinatorics
using Documenter
using HierarchicalUtils
using JSON, JSON3
using JsonGrinder
using Mill
using OneHotArrays

using JsonGrinder: update!, InconsistentSchema, IncompatibleExtractor
using LinearAlgebra: I
using Mill: Maybe

@testset "Doctests" begin
    DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, quote
        using JsonGrinder, Mill, OneHotArrays
        # do not shorten prints in doctests
        ENV["LINES"] = ENV["COLUMNS"] = typemax(Int)
    end; recursive=true)
    doctest(JsonGrinder)
end

for test_f in readdir(".")
    (endswith(test_f, ".jl") && test_f ≠ "runtests.jl") || continue
    @testset verbose = true "$test_f" begin
        include(test_f)
    end
end
