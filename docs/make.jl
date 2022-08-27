using Documenter
using JsonGrinder
using Literate

const is_ci = haskey(ENV, "GITHUB_ACTIONS")

DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, quote
    using JsonGrinder
    ENV["LINES"] = ENV["COLUMNS"] = typemax(Int)
end; recursive=true)

# generate files using literate.jl
src_dir = joinpath(@__DIR__, "src")
examples_dir = joinpath(@__DIR__, "..", "examples")
examples_generated_dir = joinpath(src_dir, "examples")
!ispath(examples_generated_dir) && mkpath(examples_generated_dir)
# the order here will be propagated to the order in the html menu
example_files = [joinpath(examples_dir, f) for f in [
    "examples.jl",
    "mutagenesis.jl",
    "recipes.jl",
    "schema_examination.jl",
    "schema_visualization.jl",
]]

function print_html_raw(str)
    str
    lines = split(str, "\n")
    html_line = findfirst(s -> occursin("<!DOCTYPE html>", s) && occursin("</html>\\n\"", s), lines)
    if isnothing(html_line)
        return str
    end
    lines[html_line-1] *= "@raw html"
    lines[html_line] = replace(lines[html_line], "\\\"" => "\"")
    lines[html_line] = replace(lines[html_line], "\\n" => "\n")
    lines[html_line] = replace(lines[html_line], "\\t" => "\t")
    lines[html_line] = replace(lines[html_line], r"\\(\w+)" => s"\1")
    join(lines, "\n")
end

example_mds = []

#for purpose of local testing
config = is_ci ? Dict() : Dict("nbviewer_root_url"=>"https://nbviewer.jupyter.org/github/CTUAvastLab/JsonGrinder.jl/blob/gh-pages/previews/PR101")
f = example_files[3]
# because there is a bug that @example blocks are not evaluated when they are included using @eval, I run the markdown code in Literate.jl
for f in example_files
    md_file = Literate.markdown(f, examples_generated_dir; config, credit = false, execute = true, postprocess = print_html_raw)
    Literate.notebook(f, examples_generated_dir; config, execute = is_ci) # Don't execute locally, because it takes long
    push!(example_mds, relpath(md_file, dirname(examples_generated_dir)))
end

# for running only doctests
is_ci && doctest(JsonGrinder)
makedocs(
         sitename = "JsonGrinder.jl",
         # doctest = false,
         format = Documenter.HTML(sidebar_sitename=false,
                                  assets=["assets/favicon.ico", "assets/custom.css"]),
         modules = [JsonGrinder],
         pages = [
                  "Home" => "index.md",
                  "Schema" => "schema.md",
                  "Creating extractors" => "extractors.md",
                  "Extractors overview" => "exfunctions.md",
                  "Examples" => example_mds,
                  "AutoML" => "automl.md",
                  "External tools" => "hierarchical.md",
                  "API Documentation" => [
                      "Public" => "api/public.md",
                      "Internal" => [
                          "Schema" => "api/internal/schema.md",
                          "Extractors" => "api/internal/extractors.md",
                      ],
                  ],
                  "Developers" => "developers.md",
                  "Citation" => "citation.md",
                  ],
)

deploydocs(
    repo = "github.com/CTUAvastLab/JsonGrinder.jl.git",
    push_preview = true
)
