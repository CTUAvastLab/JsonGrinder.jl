# JsonGrinder.jl

**JsonGrinder** is a collection of routines that facilitates conversion of JSON documents into structures used by [Mill.jl](https://github.com/CTUAvastLab/Mill.jl) project.

## Motivation

Imagine that you want to train a classifier on data looking like this
```json
{
  "ind1": 1,
  "inda": 0,
  "logp": 6.01,
  "lumo": -2.184,
  "mutagenic": 1,
  "atoms": [
	{
	  "element": "c",
	  "atom_type": 22,
	  "charge": -0.118,
	  "bonds": [
		{
		  "bond_type": 7,
		  "element": "c",
		  "atom_type": 22,
		  "charge": -0.118
		},
		{
		  "bond_type": 1,
		  "element": "h",
		  "atom_type": 3,
		  "charge": 0.141
		},
		{
		  "bond_type": 7,
		  "element": "c",
		  "atom_type": 22,
		  "charge": -0.118
		}
	  ]
	},
	⋮
	{
	  "element": "c",
	  "atom_type": 27,
	  "charge": 0.012,
	  "bonds": [
		{
		  "bond_type": 7,
		  "element": "c",
		  "atom_type": 22,
		  "charge": -0.118
		},
		{
		  "bond_type": 7,
		  "element": "c",
		  "atom_type": 27,
		  "charge": -0.089
		},
		{
		  "bond_type": 7,
		  "element": "c",
		  "atom_type": 22,
		  "charge": -0.118
		}
	  ]
	}
  ]
},

```
and the task is to predict the value in key `mutagenic` (in this sample it's `1`) from the rest of the JSON.

With most machine learning libraries assuming your data being stored as tensors of a fixed dimension, or a sequence, you will have a bad time. 
Contrary, `JsonGrider.jl` assumes your data to be stored in a flexible JSON format and tries to automate most labor using reasonable default, but it still gives you an option to control and tweak almost everything. 
`JsonGrinder.jl` is built on top of [Mill.jl](https://github.com/CTUAvastLab/Mill.jl) which itself is built on top of [Flux.jl](https://fluxml.ai/) (we do not reinvent the wheel). 
**Although JsonGrinder was designed for JSON files, you can easily adapt it to XML, [Protocol Buffers](https://developers.google.com/protocol-buffers), [MessagePack](https://msgpack.org/index.html), and other similar structures**

There are 5 steps to create a classifier once you load the data.

1. Create a schema of JSON files (using `sch = JsonGrinder.schema(...)`).
2. Create an extractor converting JSONs to Mill structures (`extractor = suggestextractor(sch)`). 
Schema `sch` from previous step is very helpful, as it helps to identify, how to convert nodes (`Dict`, `Array`) to (`Mill.ProductNode` and `Mill.BagNode`) and how to convert values in leaves to (`Float32`, `Vector{Float32}`, `String`, `Categorical`).
3. Create a model for your JSONs, which can be easily done by (using `model = reflectinmodel(sch, extractor,...)`)
4. Extract your JSON files into Mill structures using extractor `extractbatch(extractor, samples)` (at once if all data fit to memory, or per-minibatch during training)
5. Use your favourite methods to train the model, it is 100% compatible with `Flux.jl` tooling.

Steps 1 and 2 are handled by `JsonGrinder.jl`, steps 3 and 4 by combination of `Mill.jl` `JsonGrinder.jl` and the 5. step by a combination of `Mill.jl` and `Flux.jl`.

Authors see the biggest advantage in the `model` being hierarchical and reflecting the JSON structure. Thanks to `Mill.jl`, it can handle missing values at all levels.

Our idealized workflow is demonstrated in following example, which can be also found in [Mutagenesis Example](@ref) and here we'll break it down in order to demonstrate the basic functionality of JsonGrinder.

The basic workflow can be visualized as follows
```@raw html
<img src="assets/workflow.svg" alt="workflow" style="width: 30%;">
```

```@eval
import Markdown
file = joinpath(@__DIR__, "..", "src", "examples", "mutagenesis.md")
str = rstrip(join(readlines(file)[4:end], "\n"))
Markdown.parse(str)
```

This concludes a simple classifier for JSON data.

But keep in mind the framework is general and given its ability to embed hierarchical data into fixed-size vectors, it can be used for classification, regression, and various other ML tasks.
