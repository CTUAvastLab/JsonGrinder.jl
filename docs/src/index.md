# JsonGrinder.jl
`JsonGrinder.jl` is a companion to [Mill.jl](https://github.com/pevnak/Mill.jl) aimed to ease your pain when performing learning on real world data stored in JSON format. As you know, most machine learning libraries assume that your data are stored as tensors of a fixed dimension, or a sequence. Contrary, `JsonGrider.jl` assumes your data are stored in JSON format, which is flexible, and it is sufficient to convert only leaf values to a tensor, which is typically trivial. The rest is magically sorted out. 

`JsonGrinder` tries to provide reasonable defaults, but if you want, you can customize and tweak almost anything according to your imagination and desire. Last but not least, **although JsonGrinder was designed for JSON files, you can easily adapt it to XML, ProtoBuffers, MessagePacks,...**

There are four steps to create a classifier once you load the data.

1. Create a schema of JSON files (using `sch = JsonGrinder.schema`).
2. Create an extractor converting JSONs to Mill structures (`extractor = suggestextractor(sch))`). Schema `sch`  from previous step is very helpful, as it helps to identify, how to convert nodes (`Dict`, `Array`) to (`Mill.ProductNode` and `Mill.BagNode`) and how to convert values in leafs to (`Float32`, `Vector{Float32}`, `String`, `Categorical`).
3. Create a model for your JSONs, which can be easily done by (using `model = reflectinmodel(sch, extractor,...)`)
4. Use your favourite methods to train the model, it is 100% compatible with `Flux.jl` tooling.

Authors see the biggest advantage in the `model` being hierarchical and reflecting the JSON structure. Thanks to `Mill.jl`, it can handle missing values at all levels. 

Our idealized workflow is demonstrated in `examples/identification.jl` solving [device identification challenge](https://www.kaggle.com/c/cybersecprague2019-challenge/data) looks as follows (for many datasets which fits in memory it suggest just to change the key with labels (`:device_class`) and names of files):
``` julia
using Flux, MLDataPattern, Mill, JsonGrinder, JSON, IterTools, Statistics, BenchmarkTools, ThreadTools, StatsBase
using JsonGrinder: suggestextractor
using Mill: reflectinmodel

samples = map(readlines("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/dataset/train.json")) do s
           JSON.parse(s)
       end;

labelkey = "device_class"
minibatchsize = 100
iterations = 10_000
neurons = 20 		# neurons per layer

targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)
foreach(i -> delete!(i, "id"), samples)

sch = JsonGrinder.schema(samples)
extractor = suggestextractor(sch)

data = tmap(extractor, samples)
labelnames = unique(targets)

model = reflectinmodel(sch, extractor,
	k -> Dense(k, neurons, relu),
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, length(labelnames))),
)

function minibatch()
	idx = sample(1:length(data), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], zip(x, y)))

cb = () -> println("accuracy = ", accuracy(valdata...))
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))

#####
#  Classify test data
#####
test_samples = map(readlines("test.json")) do s
	extractor(JSON.parse(s))
end
o = Flux.onecold(model(reduce(catobs, test_samples)).data);
ns = extract_target[:device_class].keyvalemap
ns = Dict([ v => k for (k,v) in ns]...)
o = [ns[i] for i in o]

```


## A walkthrough of the example

Include libraries and load the data.
```julia
using Flux, MLDataPattern, Mill, JsonGrinder, JSON, IterTools, Statistics, BenchmarkTools, ThreadTools, StatsBase
using JsonGrinder: suggestextractor
using Mill: reflectinmodel

samples = map(readlines("train.json")) do s
	JSON.parse(s)
end;
```

```julia
labelkey = "device_class"
minibatchsize = 100
iterations = 10_000
neurons = 20 		# neurons per layer
```

Create labels and remove them from data, such that we do not use them as features. We also remove `id` key, such that we do not predict it
```julia
targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)
foreach(i -> delete!(i, "id"), samples)
```

Create the schema of data
```julia
sch = JsonGrinder.schema(samples)
```

Create the extractor converting jsons to Mill structure. The `suggestextractor` is executed below with default setting, but it allows you heavy customizing.
```julia
extractor = suggestextractor(sch)
```

Convert jsons to mill data samples.
```julia
data = tmap(extractor, samples)
labelnames = unique(targets)
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

