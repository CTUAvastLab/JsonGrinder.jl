using Documenter
using JsonGrinder
using Literate

const is_ci = haskey(ENV, "GITHUB_ACTIONS")

DocMeta.setdocmeta!(JsonGrinder, :DocTestSetup, :(using JsonGrinder); recursive=true)

# generate files using literate.jl
src_dir = joinpath(@__DIR__, "src")
examples_dir = joinpath(@__DIR__, "..", "examples")
examples_generated_dir = joinpath(src_dir, "examples")
!ispath(examples_generated_dir) && mkpath(examples_generated_dir)
example_files = [joinpath(examples_dir, f) for f in [
    "mutagenesis.jl",
    "recipes.jl",
    "schema_examination.jl",
    "schema_visualization.jl",
]]

str = read(joinpath(@__DIR__, "src", "examples", "schema_visualization.md"), String)
function print_html_raw(str)
    str
    lines = split(str, "\n")
    html_line = findfirst(s -> occursin("<!DOCTYPE html>", s) && occursin("</html>\\n\"", s), lines)
    if isnothing(html_line)
        return str
    end
    lines[html_start-1] *= "@raw html"
    lines[html_line] = replace(lines[html_line], "\\\"" => "\"")
    lines[html_line] = replace(lines[html_line], "\\n" => "\n")
    lines[html_line] = replace(lines[html_line], "\\t" => "\t")
    join(lines, "\n")
end

example_mds = []

#for purpose of local testing
config = is_ci ? Dict() : Dict("nbviewer_root_url"=>"https://nbviewer.jupyter.org/github/CTUAvastLab/JsonGrinder.jl/blob/gh-pages/previews/PR101")

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
                                  prettyurls=get(ENV, "CI", nothing) == "true",
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
                  "API Documentation" => "api.md",
                  "Developers" => "developers.md",
                  "Citation" => "citation.md",
                  ],

)

deploydocs(
    repo = "github.com/CTUAvastLab/JsonGrinder.jl.git",
    push_preview = true
)
