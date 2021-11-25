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

Our idealized workflow is demonstrated in following example, which can be also found in [Mutagenesis Example](@ref) and here we'll break it down in order to demonstrate the basic functionality of JsonGrinder.

```@eval
import Markdown
file = joinpath(@__DIR__, "..", "src", "examples", "mutagenesis.md")
str = rstrip(join(readlines(file)[4:end], "\n"))
Markdown.parse(str)
```

### Setup

If you want to run this tutorial yourself, you can find the notebook file [in examples firectory](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/examples/mutagenesis.ipynb).

## A walkthrough of the example

Here we include libraries and load the data. Dataset can be conveniently obtained using the [`MLDatasets` library](https://juliaml.github.io/MLDatasets.jl/stable/datasets/Mutagenesis/)

```@example mutagenesis
using MLDatasets, JsonGrinder, Flux, Mill, MLDataPattern, Statistics, ChainRulesCore
train_x, train_y = MLDatasets.Mutagenesis.traindata();
test_x, test_y = MLDatasets.Mutagenesis.testdata();
```

We define some basic parameters for the construction and training of the neural network.
```@example mutagenesis
minibatchsize = 100
iterations = 5_000
neurons = 20 		# neurons per layer
```

We create the schema of the training data, which is the first important step in using the JsonGrinder. This computes both the structure (also known as JSON schema) and histogram of occurrences of individual values in the training data.
```@example mutagenesis
sch = JsonGrinder.schema(train_x)
```

Then we use it to create the extractor converting jsons to Mill structures. The `suggestextractor` is executed below with default setting, but it allows you heavy customization.
```@example mutagenesis
extractor = suggestextractor(sch)
```

We convert jsons to mill data samples and prepare list of classes. This classification problem is two-class, but we want to infer it from labels.
The extractor is callable, so we can pass it vector of samples to obtain vector of structures with extracted features.
```@example mutagenesis
train_data = extractor.(train_x)
test_data = extractor.(test_x)
labelnames = unique(train_y)
```

We create the model reflecting structure of the data
```@example mutagenesis
model = reflectinmodel(sch, extractor,
	layer -> Dense(layer, neurons, relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, length(labelnames))),
)
```
this allows us to create model flexibly, without the need to hardcode individual layers. Individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/dev/manual/reflectin/#Model-Reflection). But briefly: for every numeric array in the sample, model will create a dense layer with `neurons` neurons (20 in this example). For every vector of observations (called bag in Multiple Instance Learning terminology), it will create aggregation function which will take mean, maximum of feature vectors and concatenate them. The `fsm` keyword argument basically says that on the end of the NN, as a last layer, we want 2 neurons `length(labelnames)` in the output layer, not 20 as in the intermediate layers.

Then, we define few handy functions and a loss function, which is categorical crossentropy in our case.
```@example mutagenesis
loss(x,y) = Flux.logitcrossentropy(inference(x), Flux.onehotbatch(y, labelnames))

inference(x::AbstractMillNode) = model(x).data
inference(x::AbstractVector{<:AbstractMillNode}) = inference(reduce(catobs, x))
accuracy(x,y) = mean(labelnames[Flux.onecold(inference(x))] .== y)
loss(xy::Tuple) = loss(xy...)

@non_differentiable Base.reduce(catobs, x::AbstractVector{<:AbstractMillNode})
```

And we can add a callback which will be printing train and test accuracy during the training
and then we can start trining
```@repl mutagenesis
cb = () -> begin
	train_acc = accuracy(train_data, train_y)
	test_acc = accuracy(test_data, test_y)
	println("accuracy: train = $train_acc, test = $test_acc")
end
```

Lastly we turn our training data to minibatchers and we can start training
```@repl mutagenesis
minibatches = RandomBatches((train_data, train_y), size = minibatchsize, count = iterations)
Flux.Optimise.train!(loss, Flux.params(model), minibatches, ADAM(), cb = Flux.throttle(cb, 2))
```

We can see the accuracy rising and obtaining over 98% on training set quite quickly, and on test set we get over 70%.

Last part is inference on test data
```@repl mutagenesis
probs = softmax(inference(test_data))
o = Flux.onecold(probs)
pred_classes = labelnames[o]

print(mean(pred_classes .== test_y))
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
