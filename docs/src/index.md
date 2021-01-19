# JsonGrinder.jl

**JsonGrinder** is a collection of routines that facilitates conversion of JSON documents into structures used by [Mill.jl](https://github.com/pevnak/Mill.jl) project.

## Motivation

Imagine that you want to train a classifier on data looking like
```json
{
  "services": [
    {
      "protocol": "tcp",
      "port": 80
    },
    {
      "protocol": "tcp",
      "port": 443
    },
  ],
  "ip": "192.168.1.109",
  "device_id": "2717684b-3937-4644-a33a-33f4226c43ec",
  "upnp": [
    {
      "device_type": "urn:schemas-upnp-org:device:MediaServer:1",
      "services": [
        "urn:upnp-org:serviceId:ContentDirectory",
        "urn:upnp-org:serviceId:ConnectionManager"
      ],
      "manufacturer": "ARRIS",
      "model_name": "Verizon Media Server",
      "model_description": "Media Server"
    }
  ],
  "device_class": "MEDIA_BOX",
  "ssdp": [
    {
      "st": "",
      "location": "http://192.168.1.109:9098/device_description.xml",
      "method": "",
      "nt": "upnp:rootdevice",
      "server": "ARRIS DIAL/1.7.2 UPnP/1.0 ARRIS Settop Box",
      "user_agent": ""
    },
    {
      "st": "",
      "location": "http://192.168.1.109:8091/XD/21e13e66-1dd2-11b2-9b87-44e137a2ec6a",
      "method": "",
      "nt": "upnp:rootdevice",
      "server": "Allegro-Software-RomPager/5.41 UPnP/1.0 ARRIS Settop Box",
      "user_agent": ""
    },
   ],
  "mac": "44:e1:37:a2:ec:c1"
}
```
With most machine learning libraries assuming your data being stored as tensors of a fixed dimension, or a sequence, you will have a bad time. Contrary, `JsonGrider.jl` assumes your data to be stored in a flexible JSON format and tries to automate most labor using reasonable default, but it still gives you an option to control and tweak almost everything. `JsonGrinder.jl` is built on top of [Mill.jl](https://github.com/pevnak/Mill.jl) which itself is built on top of [Flux.jl](https://fluxml.ai/) (we do not reinvent the wheel). **Although JsonGrinder was designed for JSON files, you can easily adapt it to XML, [Protocol Buffers](https://developers.google.com/protocol-buffers), [MessagePack](https://msgpack.org/index.html), and other similar structures**

There are four steps to create a classifier once you load the data.

1. Create a schema of JSON files (using `sch = JsonGrinder.schema`).
2. Create an extractor converting JSONs to Mill structures (`extractor = suggestextractor(sch))`). Schema `sch` from previous step is very helpful, as it helps to identify, how to convert nodes (`Dict`, `Array`) to (`Mill.ProductNode` and `Mill.BagNode`) and how to convert values in leaves to (`Float32`, `Vector{Float32}`, `String`, `Categorical`).
3. Create a model for your JSONs, which can be easily done by (using `model = reflectinmodel(sch, extractor,...)`)
4. Use your favourite methods to train the model, it is 100% compatible with `Flux.jl` tooling.

The first two steps are handled by `JsonGrinder.jl` the third step by `Mill.jl` and the fourth by a combination of `Mill.jl` and `Flux.jl`.

Authors see the biggest advantage in the `model` being hierarchical and reflecting the JSON structure. Thanks to `Mill.jl`, it can handle missing values at all levels.

## Example
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
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, length(labelnames))),
)

#####
#  Train the model
#####
function minibatch()
	idx = sample(1:length(data), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], zip(x, y)))

cb = () -> println("accuracy = ", accuracy(data, targets))
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

Create the extractor converting jsons to Mill structure. The `suggestextractor` is executed below with default setting, but it allows you heavy customization.
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

individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://pevnak.github.io/Mill.jl/dev/manual/reflectin/#Model-Reflection)

Lastly, we define few handy functions and then we start training.
```julia
function minibatch()
	idx = sample(1:length(data), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], zip(x, y)))

cb = () -> println("accuracy = ", accuracy(data, targets))
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))
```
