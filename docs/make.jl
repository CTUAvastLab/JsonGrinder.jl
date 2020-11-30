using Documenter
using JsonGrinder

makedocs(
    sitename = "JsonGrinder",
    format = Documenter.HTML(),
    modules = [JsonGrinder],
    pages = ["Home" => "index.md",
    "Schema" => "schema.md",
    "Extractors" => "extractors.md",
	],

)

deploydocs(
    repo = "github.com/pevnak/JsonGrinder.jl.git",
)
