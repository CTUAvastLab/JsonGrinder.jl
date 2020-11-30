# JsonGrinder.jl
`JsonGrinder.jl` is a companion to [Mill.jl](https://github.com/pevnak/Mill.jl) aimed to ease your pain when performing learning on real world data stored in JSON format.

Our imagined workflow consists to build classifier by Machine Learning over JSONs consists of following steps.

1. Create a schema of JSON files (using `sch = JsonGrinder.schema`).
2. Create an extractor converting JSONs to internal Mill structure (`extractor = suggestextractor(sch))`)
3. Create a model for your JSONs (using `model = reflectinmodel(sch, extractor,...)`)

We see the biggest advantage in the `model` being hierarchical reflecting the JSON structure. Naturally, it can handle missing values at all levels. 


Our idealized workflow (taken from `examples/recipes.jl`) would look as follows. The recipe dataset is utterly boring (and were recommend `deviceid`), but it is a good start. The code below relies heavily on defaults. We thrive to make everything as customization as possible and details about individual steps are listed in appropriate sections. Recall that from creation of the model onward, you might need to consult `Mill.jl`.

Include libraries and load the data.
```julia
using Flux, MLDataPattern, Mill, JsonGrinder, JSON, IterTools, Statistics, BenchmarkTools, ThreadTools
using JsonGrinder: suggestextractor
using Mill: reflectinmodel

jsons = open("examples/recipes.json","r") do fid
	Vector{Dict}(JSON.parse(read(fid, String)))
end
```

```julia
	labelkey = "cuisine"
	minibatchsize = 100
	iterations = 10_000
	neurons = 20 		# neurons per layer
```

Create labels and remove them from data, such that we do not use them as features. We also remove `id` key, such that we do not predict it
```julia
targets = map(i -> i[labelkey], jsons)
foreach(i -> delete!(i, labelkey), jsons)
foreach(i -> delete!(i, "id"), jsons)
```

Create the schema of data
```julia
sch = JsonGrinder.schema(jsons)
```

Create the extractor converting jsons to Mill structure. The `suggestextractor` is executed below with default setting, but it allows you heavy customizing.
```julia
extractor = suggestextractor(sch)
```

Convert jsons to mill data samples.
```julia
data = tmap(extractor, jsons)
labelnames = unique(targets)
```

Split data to training and testing set.
```julia
valdata = data[1:1_000], targets[1:1_000]
data, targets = data[1_001:end], targets[1001:end]
```

Create the model according to the data
```julia
model = reflectinmodel(sch, extractor,
	k -> Dense(k, neurons, relu),
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, length(labelnames))),
)
```

After definiting few usual function, we start training.
```julia
function minibatch()
	idx = sample(1:length(data), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], zip(x, y)))

cb = () -> println("accuracy = ", accuracy(valdata...))
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))
```

