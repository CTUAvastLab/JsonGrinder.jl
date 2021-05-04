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

With most machine learning libraries assuming your data being stored as tensors of a fixed dimension, or a sequence, you will have a bad time. Contrary, `JsonGrider.jl` assumes your data to be stored in a flexible JSON format and tries to automate most labor using reasonable default, but it still gives you an option to control and tweak almost everything. `JsonGrinder.jl` is built on top of [Mill.jl](https://github.com/CTUAvastLab/Mill.jl) which itself is built on top of [Flux.jl](https://fluxml.ai/) (we do not reinvent the wheel). **Although JsonGrinder was designed for JSON files, you can easily adapt it to XML, [Protocol Buffers](https://developers.google.com/protocol-buffers), [MessagePack](https://msgpack.org/index.html), and other similar structures**

There are four steps to create a classifier once you load the data.

1. Create a schema of JSON files (using `sch = JsonGrinder.schema`).
2. Create an extractor converting JSONs to Mill structures (`extractor = suggestextractor(sch))`). Schema `sch` from previous step is very helpful, as it helps to identify, how to convert nodes (`Dict`, `Array`) to (`Mill.ProductNode` and `Mill.BagNode`) and how to convert values in leaves to (`Float32`, `Vector{Float32}`, `String`, `Categorical`).
3. Extract your JSON files into Mill structures using extractor `extractbatch(extractor, samples)`
4. Create a model for your JSONs, which can be easily done by (using `model = reflectinmodel(sch, extractor,...)`)
5. Use your favourite methods to train the model, it is 100% compatible with `Flux.jl` tooling.

The first three steps are handled by `JsonGrinder.jl`, the fourth step by `Mill.jl` and the fourth by a combination of `Mill.jl` and `Flux.jl`.

Authors see the biggest advantage in the `model` being hierarchical and reflecting the JSON structure. Thanks to `Mill.jl`, it can handle missing values at all levels.

## Example
Our idealized workflow is demonstrated in `examples/mutagenesis.jl` [determining mutagenicity on Salmonella typhimurium](https://relational.fit.cvut.cz/dataset/Mutagenesis) (dataset is stored in json format [inside JsonGrinder.jl repo](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/data/mutagenesis) for your convenience) and it looks as follows (for many datasets which fits in memory it's sufficient just to change the key with labels (`labelkey`) and names of files to use the example on them):
```julia
using Flux, MLDataPattern, Mill, JsonGrinder, JSON, Statistics, IterTools, StatsBase, ThreadTools
using JsonGrinder: suggestextractor, ExtractDict
using Mill: reflectinmodel

samples = Vector{Dict}(open(JSON.parse, "../data/mutagenesis/data.json"))

metadata = open(JSON.parse, "data/mutagenesis/meta.json")
labelkey = metadata["label"]
test_num = metadata["test_samples"]
minibatchsize = 100
iterations = 1_000
neurons = 20 		# neurons per layer

targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)

train_indices = 1:length(samples)-test_num
test_indices = length(samples)-test_num+1:length(samples)

#####
#  Create the schema and extractor
#####
sch = JsonGrinder.schema(samples)
extractor = suggestextractor(sch)

#####
#  Convert samples to Mill structure and extract targets
#####
data = tmap(extractor, samples)
labelnames = unique(targets)

#####
#  Create the model
#####
model = reflectinmodel(sch, extractor,
	k -> Dense(k, neurons, relu),
	d -> meanmax_aggregation(d),
	fsm = Dict("" => k -> Dense(k, length(labelnames))),
)

#####
#  Train the model
#####
function minibatch()
	idx = sample(1:length(data[train_indices]), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(labelnames[Flux.onecold(model(x).data)] .== y)

trainset = reduce(catobs, data[train_indices])
testset = reduce(catobs, data[test_indices])

cb = () -> begin
	train_acc = accuracy(trainset, targets[train_indices])
	test_acc = accuracy(testset, targets[test_indices])
	println("accuracy: train = $train_acc, test = $test_acc")
end
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))

###############################################################
#  Classify test set
###############################################################

probs = softmax(model(testset).data)
o = Flux.onecold(probs)
pred_classes = labelnames[o]

print(mean(pred_classes .== targets[test_indices]))
# we see the accuracy is around 79% on test set

#predicted classes for test set
print(pred_classes)
#gt classes for test set
print(targets[test_indices])
# probabilities for test set
print(probs)
```

## A walkthrough of the example

Here we include libraries and load the data.
```@example mutagenesis
using Flux, MLDataPattern, Mill, JsonGrinder, JSON, Statistics, IterTools, StatsBase, ThreadTools
using JsonGrinder: suggestextractor, ExtractDict
using Mill: reflectinmodel
samples = Vector{Dict}(open(JSON.parse, "../../data/mutagenesis/data.json"))
```

we load metadata, which store which class is to be predicted and how many samples to be used for testing
```@example mutagenesis
metadata = open(JSON.parse, "../../data/mutagenesis/meta.json")
test_num = metadata["test_samples"]
minibatchsize = 100
iterations = 1_000
neurons = 20 		# neurons per layer
labelkey = metadata["label"]
```

we see  that label to be predicted is `mutagenic`.

We create labels and remove them from data, such that we do not use them as features. We also prepare indices of train and test data here.
```@example mutagenesis
targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)

train_indices = 1:length(samples)-test_num
test_indices = length(samples)-test_num+1:length(samples)
```

We create the schema of data
```@example mutagenesis
sch = JsonGrinder.schema(samples)
```

Then we use it to create the extractor converting jsons to Mill structure. The `suggestextractor` is executed below with default setting, but it allows you heavy customization.
```@example mutagenesis
extractor = suggestextractor(sch)
```

We convert jsons to mill data samples.
```@example mutagenesis
data = tmap(extractor, samples)
labelnames = unique(targets)
```

We create the model reflecting structure of the data
```@example mutagenesis
model = reflectinmodel(sch, extractor,
	k -> Dense(k, neurons, relu),
	d -> meanmax_aggregation(d),
	fsm = Dict("" => k -> Dense(k, length(labelnames))),
)
```

individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/dev/manual/reflectin/#Model-Reflection)

Lastly, we define few handy functions.
```@example mutagenesis
function minibatch()
	idx = sample(1:length(data[train_indices]), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(labelnames[Flux.onecold(model(x).data)] .== y)

trainset = reduce(catobs, data[train_indices])
testset = reduce(catobs, data[test_indices])

cb = () -> begin
	train_acc = accuracy(trainset, targets[train_indices])
	test_acc = accuracy(testset, targets[test_indices])
	println("accuracy: train = $train_acc, test = $test_acc")
end
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
```

and then we can start trining
```@repl mutagenesis
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))
```

We can see the accuracy rising and obtaining over 98% on training set quite quickly, and on test set we get over 70%.

Last part is inference on test data
```@repl mutagenesis
probs = softmax(model(testset).data)
o = Flux.onecold(probs)
pred_classes = labelnames[o]

print(mean(pred_classes .== targets[test_indices]))
```

`pred_classes` contains the predictions for our test set.

We can look at individual samples. For instance, first sample in te `test_samples[2]` is
```json
{
  "ind1": 1,
  "inda": 0,
  "logp": 3.92,
  "lumo": -3.406,
  "mutagenic": 1,
  "atoms": [
	{
	  "element": "c",
	  "atom_type": 22,
	  "charge": -0.109,
	  "bonds": [
		{
		  "bond_type": 1,
		  "element": "h",
		  "atom_type": 3,
		  "charge": 0.151
		},
		...
		{
		  "bond_type": 7,
		  "element": "c",
		  "atom_type": 22,
		  "charge": -0.109
		}
	  ]
	}
	...
	]
}
```

and the corresponding classification is
```@repl mutagenesis
pred_classes[1]
```

if you want to see the probability distribution, it can be obtained by applying `softmax` to the output of the network.
```@repl mutagenesis
softmax(model(testset[1]).data)
```

so we can see that the probability that given sample is `mutagenetic` is almost 1.

This concludes a simple classifier for JSON data.

But keep in mind the framework is general and given its ability to embed hierarchical data into fixed-size vectors, it can be used for classification, regression, and various other ML tasks.
