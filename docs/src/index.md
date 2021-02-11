# JsonGrinder.jl

**JsonGrinder** is a collection of routines that facilitates conversion of JSON documents into structures used by [Mill.jl](https://github.com/CTUAvastLab/Mill.jl) project.

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
Our idealized workflow is demonstrated in `examples/identification.jl` solving [device identification challenge](https://www.kaggle.com/c/cybersecprague2019-challenge/data) looks as follows (for many datasets which fits in memory it suggest just to change the key with labels (`:device_class`) and names of files):
```julia
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

accuracy(x,y) = map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], x, y) |> mean

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
iterations = 5_000
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

individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/dev/manual/reflectin/#Model-Reflection)

Lastly, we define few handy functions and then we start training.
```julia
function minibatch()
	idx = sample(1:length(data), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], x, y) |> mean

cb = () -> println("accuracy = ", accuracy(data, targets))
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))
```

We should see something like
```
accuracy = 0.1104894138776638
accuracy = 0.45656754049666703
accuracy = 0.8238869892584534
accuracy = 0.893102614582254
accuracy = 0.9316651124235831
accuracy = 0.9554795703381342
accuracy = 0.9693468725175284
accuracy = 0.975166649397299
accuracy = 0.9758056159983421
accuracy = 0.978465098608089
accuracy = 0.9825752080958795
accuracy = 0.9840949124443062
accuracy = 0.9837495250923911
accuracy = 0.9853037681760094
accuracy = 0.9850965357648603
accuracy = 0.9861499671882016
accuracy = 0.9881359444617138
accuracy = 0.9886540254895866
accuracy = 0.9903118847787794
accuracy = 0.9901219217352261
accuracy = 0.9905363865575243
accuracy = 0.9911408144233759
accuracy = 0.9913135080993334
accuracy = 0.9903809622491624
```

accuracy rising and obtaining over 98% on training set quite quickly.

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
"GAME_CONSOLE"
```

if you want to see the probability distribution, it can be obtained by applying `softmax` to the output of the network.
```julia
julia> softmax(model(test_data[2]).data)
13×1 Array{Float32,2}:
2.2447991f-6
0.0006994973
7.356086f-5
0.9131056
0.00015438742
2.277255f-6
1.2209773f-5
0.07608723
0.0024369168
0.0012505687
0.006140974
3.3941535f-5
3.9533225f-7
```

so we can see that the probability that given sample is `GAME_CONSOLE` is ~91% (in 4th element of array).

This concludes a simple classifier for JSON data.

But keep in mind the framework is general and given its ability to embed hierarchical data into fixed-size vectors, it can be used for classification, regression, and various other ML tasks.
