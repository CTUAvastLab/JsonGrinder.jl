using JsonGrinder
using Mill
using OneHotArrays
using Test
using Setfield
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

for test_f in readdir(".")
    (endswith(test_f, ".jl") && test_f ≠ "runtests.jl") || continue
    @testset verbose = true "$test_f" begin
        include(test_f)
    end
end
