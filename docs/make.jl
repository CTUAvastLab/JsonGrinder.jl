using Documenter
using JsonGrinder
using Literate

DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, :(using JsonGrinder); recursive=true)

# generate files using literate.jl
examples_dir = joinpath(@__DIR__, "..", "examples")
examples_generated_dir = joinpath(examples_dir, "generated")
mutagenesis_file = joinpath(examples_dir, "mutagenesis.jl")

Literate.markdown(mutagenesis_file, examples_generated_dir; credit = false)
Literate.script(mutagenesis_file, examples_generated_dir)
Literate.notebook(mutagenesis_file, examples_generated_dir)

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
