using Test, Random

Random.seed!(0)

using JsonGrinder
using JsonGrinder: update!, InconsistentSchema

using Combinatorics
using Documenter
using JSON
using Random

# function buf_printtree(data; kwargs...)
#     buf = IOBuffer()
#     printtree(buf, data; kwargs...)
#     String(take!(buf))
# end

const ≃ = isequal

# @testset "Doctests" begin
#     DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, quote
#         using JsonGrinder, Mill, OneHotArrays
#         # do not shorten prints in doctests
#         ENV["LINES"] = ENV["COLUMNS"] = typemax(Int)
#     end; recursive=true)
#     doctest(JsonGrinder)
# end

# TODO tests for io, like in Mill.jl

# for test_f in readdir(".")
for test_f in ["leaf.jl", "schema.jl"]
    (endswith(test_f, ".jl") && test_f ≠ "runtests.jl") || continue
    @testset verbose = true "$test_f" begin
        include(test_f)
    end
end
