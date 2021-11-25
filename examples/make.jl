# the logic is that we generate script from the example so we can utilize #src and #!src things
using Literate

const is_ci = haskey(ENV, "GITHUB_ACTIONS")

# generate files using literate.jl
examples_dir = @__DIR__
examples_generated_dir = joinpath(@__DIR__, "generated")
!ispath(examples_generated_dir) && mkpath(examples_generated_dir)
example_files = [joinpath(examples_dir, f) for f in [
    "recipes.jl",
    "schema_examination.jl",
    "schema_visualization.jl",
]]

for f in example_files
    Literate.script(f, examples_generated_dir)
end
