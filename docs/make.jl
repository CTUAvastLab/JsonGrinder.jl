using Documenter
using JsonGrinder
using Literate

const is_ci = haskey(ENV, "GITHUB_ACTIONS")

DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, :(using JsonGrinder); recursive=true)

# generate files using literate.jl
examples_dir = joinpath(@__DIR__, "..", "examples")
examples_generated_dir = joinpath(@__DIR__, "src", "examples")
!ispath(examples_generated_dir) && mkpath(examples_generated_dir)
example_files = [joinpath(examples_dir, f) for f in [
    "mutagenesis.jl",
    "recipes.jl",
    "schema_examination.jl",
    "schema_visualization.jl",
]]

example_mds = []
for f in example_files
    md_file = Literate.markdown(f, examples_generated_dir; credit = false)
    Literate.notebook(f, examples_generated_dir, execute = is_ci) # Don't execute locally, because it takes long
    push!(example_mds, relpath(md_file, dirname(examples_generated_dir)))
end
@show example_mds

# for running only doctests
doctest(JsonGrinder)
makedocs(
         sitename = "JsonGrinder.jl",
         # doctest = false,
         format = Documenter.HTML(sidebar_sitename=false,
                                  prettyurls=get(ENV, "CI", nothing) == "true",
                                  assets=["assets/favicon.ico", "assets/custom.css"]),
         modules = [JsonGrinder],
         pages = ["Home" => "index.md",
                  "Schema" => "schema.md",
                  "Creating extractors" => "extractors.md",
                  "Extractors overview" => "exfunctions.md",
                  "Examples" => example_mds,
                  "AutoML" => "automl.md",
                  "External tools" => "hierarchical.md",
                  "API Documentation" => "api.md",
                  "Developers" => "developers.md",
                  "Citation" => "citation.md"
                  ],

)

deploydocs(
    repo = "github.com/CTUAvastLab/JsonGrinder.jl.git",
    push_preview = true
)
