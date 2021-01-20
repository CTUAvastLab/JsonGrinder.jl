# JsonGrinder.jl

**JsonGrinder** is a collection of routines that facilitates conversion of JSON documents into structures used by [Mill.jl](https://github.com/pevnak/Mill.jl) project.

## Motivation

Imagine that you want to train a classifier on data looking like this
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
and the task is to predict the value in key `device_class` (in this sample it's `MEDIA_BOX`) from the rest of the JSON.

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
using Flux, MLDataPattern, Mill, JsonGrinder, JSON, IterTools, Statistics, ThreadTools, StatsBase
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
foreach(i -> delete!(i, "device_id"), samples)

#####
#  Create the schema and extractor
#####
sch = schema(samples)
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
	fsm = Dict("" => k -> Dense(k, length(labelnames))),
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
test_samples = map(JSON.parse, readlines("data/dataset/test.json"))
test_data = tmap(extractor, test_samples)
o = Flux.onecold(model(reduce(catobs, test_data)).data)
predicted_classes = labelnames[o]

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

Create labels and remove them from data, such that we do not use them as features. We also remove `device_id` key, such that we do not predict it
```julia
targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)
foreach(i -> delete!(i, "device_id"), samples)
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
	fsm = Dict("" => k -> Dense(k, length(labelnames))),
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

We should see something like
```
accuracy = 0.09138949331675474
accuracy = 0.19093012813870755
accuracy = 0.24213380306013194
accuracy = 0.28872655683348875
accuracy = 0.32968949677062825
accuracy = 0.7267295271647153
accuracy = 0.8373916347183367
accuracy = 0.8743480813732601
accuracy = 0.8886298483749525
accuracy = 0.9020999550996442
accuracy = 0.9089213552999689
accuracy = 0.9155182537215487
accuracy = 0.920940835146617
accuracy = 0.926518840880047
accuracy = 0.9258971436465997
accuracy = 0.9276931578765586
accuracy = 0.9289883604462404
accuracy = 0.9305080647946672
accuracy = 0.9309225296169654
accuracy = 0.931526957482817
accuracy = 0.9333057023451801
accuracy = 0.9349808310019687
accuracy = 0.9332884329775843
accuracy = 0.9330812005664353
accuracy = 0.9359997236901184
accuracy = 0.9372431181570131
accuracy = 0.9357924912789694
accuracy = 0.9347390598556281
accuracy = 0.9369840776430767
accuracy = 0.9368286533347149
```

accuracy rising and obtaining over 93% on training set quite quickly.

Last part is inference on test data
```julia
test_samples = map(JSON.parse, readlines("data/dataset/test.json"))
test_data = tmap(extractor, test_samples)
o = Flux.onecold(model(reduce(catobs, test_data)).data)
predicted_classes = labelnames[o]
```

`predicted_classes` contains the predictions for our test set.

We can look at individual samples. For instance, `test_samples[2]` is
```json
{
    "mac":"64:b5:c6:66:2b:ab",
    "ip":"192.168.1.46",
    "dhcp":[
        {
            "paramlist":"1,3,6,15,28,33",
            "classid":""
        }
    ],
    "device_id":"addb3142-6b4a-4aef-9d00-ce7ab250c05c"
}
```

and the corresponding classification is
```julia
julia> predicted_classes[2]
"GENERIC_IOT"
```

if you want to see the probability distribution, it can be obtained by applying `softmax` to the output of the network.
```julia
julia> softmax(model(test_data[2]).data)
13×1 Array{Float32,2}:
 0.0015072504
 0.009823966
 0.00017151577
 0.00082577823
 0.86119044
 0.017357541
 0.0006594112
 0.0073490166
 0.020295186
 0.006199604
 0.010532198
 0.06407002
 1.791575f-5
```

so we can see that the probability that given sample is `GENERIC_IOT` is ~86% (in 5th element of array).

This concludes a simple classifier for JSON data.

But keep in mind the framework is general and given its ability to embed hierarchical data into fixed-size vectors, it can be used for classification, regression, and various other ML tasks.
