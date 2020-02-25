using JsonGrinder
using JSON

import JsonGrinder: generate_html

#load all samples
samples_str = open("examples/recipes.json") do fid
	read(fid, String)
end;

samples = convert(Vector{Dict}, JSON.parse(samples_str));

#print example of the JSON
JSON.print(samples[1],2)

#create schema of the json
sch = JsonGrinder.schema(samples)

# generate html, keeping only 100 unique values per item
generate_html(sch, "recipes_max_vals=100.html", max_vals=100)

#generate html, keep all values from schema
generate_html(sch, "recipes.html", max_vals=nothing)

using ElectronDisplay
using ElectronDisplay: displayhtml, newdisplay
displayhtml(newdisplay(),generate_html(sch, max_vals = 100))
