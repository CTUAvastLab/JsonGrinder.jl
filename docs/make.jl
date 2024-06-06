using JsonGrinder, Mill
using Pkg, Documenter, Literate

#=
Useful resources for writing docs:
    Julia guidelines: https://docs.julialang.org/en/v1/manual/documentation/
    Documenter syntax: https://juliadocs.github.io/Documenter.jl/stable/man/syntax/ 
    Showcase: https://juliadocs.github.io/Documenter.jl/stable/showcase/
    Doctests: https://juliadocs.github.io/Documenter.jl/stable/man/doctests/

To locally browse the docs, use

python3 -m http.server --bind localhost

in the build directory.

or

julia -e 'using LiveServer; serve(dir="build")'
=#

examples_path = joinpath(@__DIR__, "src", "examples")
for e in readdir(examples_path)
    example_path = joinpath(examples_path, e)
    Pkg.activate(example_path) do
        Pkg.update()
        Pkg.instantiate()

        add_setup(s) = """
        ```@setup $e
        using Pkg
        old_path = Pkg.project().path
        Pkg.activate(pwd())
        Pkg.instantiate()
        ```
        """ * s * """
        ```@setup $e
        Pkg.activate(old_path)
        ```
        """

        literate_file = joinpath(example_path, "$(e)_literate.jl")
        Literate.markdown(literate_file, example_path, name=e, credit=false, postprocess=add_setup)
        Literate.script(literate_file, example_path, name=e, credit=false)
        Literate.notebook(literate_file, example_path, name=e)
    end
end

makedocs(
         sitename = "JsonGrinder.jl", modules = [JsonGrinder], doctest = false,
         format = Documenter.HTML(sidebar_sitename=false,
                                  assets=["assets/favicon.ico", "assets/custom.css"]),
         warnonly = Documenter.except(:eval_block, :example_block, :meta_block, :setup_block),
         pages = [
                  "Home" => "index.md",
                  "Motivation" => "motivation.md",
                  "Manual" => [
                      "Schema inference" => "manual/schema_inference.md",
                      "Extraction" => "manual/extraction.md",
                  ],
                  "Examples" => [
                        "Mutagenesis" => "examples/mutagenesis/mutagenesis.md",
                        "Recipes" => "examples/recipes/recipes.md",
                  ],
                  "External tools" => [
                      "HierarchicalUtils.jl" => "tools/hierarchical.md",
                      "Hyperopt.jl" => "tools/hyperopt.md"
                  ],
                  "Public API" => [
                      "Schema" => "api/schema.md",
                      "Extractors" => "api/extractor.md",
                  ],
                  "Citation" => "citation.md"
                  ],
        )

deploydocs(repo = "github.com/CTUAvastLab/JsonGrinder.jl.git")
