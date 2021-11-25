using JsonGrinder
using JSON

import JsonGrinder: generate_html

#load all samples
data_file = "data/recipes.json" #src
data_file = "../../../data/recipes.json" #nb
data_file = "../../../data/recipes.json" #md
data_file = "../data/recipes.json" #jl
samples_str = open(data_file) do fid
	read(fid, String)
end;

samples = convert(Vector{Dict}, JSON.parse(samples_str));

#print example of the JSON
JSON.print(samples[1],2)

#create schema of the json
sch = JsonGrinder.schema(samples)

# generate html, keeping only 100 unique values per item
generate_html("recipes_max_vals=100.html", sch, max_vals=100)

#generate html, keep all values from schema
generate_html("recipes.html", sch, max_vals=nothing)

using ElectronDisplay
using ElectronDisplay: newdisplay
generated_html = generate_html(sch, max_vals = 100)
# this hangs the CI
# display(newdisplay(), MIME{Symbol("text/html")}(), generated_html)
print("opened electron display")

using ElectronDisplay: displayhtml, newdisplay
# this hangs the CI
# displayhtml(newdisplay(), generated_html)
print("opened another electron display")
