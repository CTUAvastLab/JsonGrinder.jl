# # Schema Visualization
# In this example we show how can schema be turned into HTML interactive visualization, which helps to examine the schema,
# especially when dealing with large and heterogeneous data.

#md # !!! tip
#md #     This example is also available as a Jupyter notebook, feel free to run it yourself:
#md #     [`schema_visualization.ipynb`](@__NBVIEWER_ROOT_URL__/examples/schema_visualization.ipynb)

#nb # We start by installing JsonGrinder and few other packages we need for the example.
#nb # Julia Ecosystem follows philosophy of many small single-purpose composable packages
#nb # which may be different from e.g. python where we usually use fewer larger packages.
#nb using Pkg
#nb pkg"add JsonGrinder#master JSON"

# We include packages we want to use.
using JsonGrinder, JSON
import JsonGrinder: generate_html

# Now we load all samples
data_file = "data/recipes.json" #src
data_file = "../../../data/recipes.json" #nb
data_file = "../../../data/recipes.json" #md
data_file = "data/recipes.json" #jl
samples_str = open(data_file) do fid
	read(fid, String)
end;

# We parse them to structures
samples = convert(Vector{Dict}, JSON.parse(samples_str));

# Print example of the JSON
JSON.print(samples[1],2)

# We create schema from all samples
sch = JsonGrinder.schema(samples)

# Now we can generate the html visualization into a file, keeping only 100 unique values per item
generate_html("recipes_max_vals=100.html", sch, max_vals=100)

# Or we can generate html, keeping all values from schema.
generate_html("recipes.html", sch, max_vals=nothing)

# If we omit the first argument, we will get the html as a string
generated_html = generate_html(sch, max_vals = 100);

# Now we can look at the visualization.
#
# Feel free to click the triangles, individual nodes of the tree are collapsed by default,
# but can be expanded or collapsed when clicked. This way you can easily examine individual parts of the schema.
# For lists we show histograms of lengths, for leaves we show histogram of values etc.
generated_html

# If you like, you may use the Electron to open it in browser.
# using the following code (this works if you run it from REPL, but not from jupyter notebook or in CI)
# ```julia
# using ElectronDisplay
# using ElectronDisplay: newdisplay
# display(newdisplay(), MIME{Symbol("text/html")}(), generated_html)
# ```
