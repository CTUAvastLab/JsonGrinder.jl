using Literate

target_dir = joinpath(@__DIR__, "generated")
mkpath(target_dir)

for f in [
    "recipes.jl",
    "mutagenesis.jl",
    "schema_examination.jl",
    "schema_visualization.jl",
]
    Literate.script(joinpath(@__DIR__, f), target_dir)
end
