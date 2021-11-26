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

example_mds = []

#for purpose of local testing
config = is_ci ? Dict() : Dict("nbviewer_root_url"=>"https://nbviewer.jupyter.org/github/CTUAvastLab/JsonGrinder.jl/blob/gh-pages/previews/PR101")

# because there is a bug that @example blocks are not evaluated when they are included using @eval, I run the markdown code in Literate.jl
for f in example_files
    md_file = Literate.markdown(f, examples_generated_dir; config, credit = false, execute = true)
    Literate.notebook(f, examples_generated_dir; config, execute = is_ci) # Don't execute locally, because it takes long
    push!(example_mds, relpath(md_file, dirname(examples_generated_dir)))
end

# because there is a bug that @example blocks are not evaluated when they are included using @eval, I do it manually
# generated_path = joinpath(src_dir, "generated")
# !ispath(generated_path) && mkpath(generated_path)
# open(joinpath(generated_path, "index.md"), "w+") do io
#     write(io, read("$src_dir/index_header.md"))
#     write(io, read("$examples_dir/mutagenesis.md"))
#     write(io, read("$src_dir/index_footer.md"))
# end


# for running only doctests
doctest(JsonGrinder)
makedocs(
         sitename = "JsonGrinder.jl",
         # doctest = false,
         format = Documenter.HTML(sidebar_sitename=false,
                                  prettyurls=get(ENV, "CI", nothing) == "true",
                                  assets=["assets/favicon.ico", "assets/custom.css"]),
         modules = [JsonGrinder],
         pages = [
#                   "Home" => "generated/index.md",
                  "Home" => "index.md",
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
