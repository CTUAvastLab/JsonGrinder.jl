# # Recipe Ingredients Example
# Following example demonstrates prediction of cuisine from set of ingredients.
# For simplicity, the repo contains small subset of the dataset, the whole dataset and problem description can
# be found [on this Kaggle page](https://www.kaggle.com/kaggle/recipe-ingredients-dataset/home).

#md # !!! tip
#md #     This example is also available as a Jupyter notebook:
#md #     [`mutagenesis.ipynb`](@__NBVIEWER_ROOT_URL__/examples/recipes.ipynb)

using MLDatasets, JsonGrinder, Flux, Mill, MLDataPattern, Statistics, ChainRulesCore
using JSON

# start by loading all samples
#src magic for resolving paths
data_file = "data/recipes.json" #src
#!src data_file = "../../../data/recipes.json"
samples = open(data_file,"r") do fid
	Vector{Dict}(JSON.parse(read(fid, String)))
end
JSON.print(samples[1],2)

# create schema of the JSON
sch = JsonGrinder.schema(samples)

# create extractor and split it into one for loading targets and
# one for loading data, using custom function to set conditions for using n-gram representation
delete!(sch.childs,:id)

extractor = suggestextractor(sch)
extract_data = ExtractDict(deepcopy(extractor.dict))
extract_target = ExtractDict(deepcopy(extractor.dict))
delete!(extract_target.dict, :ingredients)
delete!(extract_data.dict, :cuisine)

extract_data(samples[1])
extract_target(samples[1])[:cuisine]
# we convert JSONs to Datasets
# advised to use all the samples, this is just speedup to demonstrate functionality
data = extract_data.(samples[1:5_000])
data = reduce(catobs, data)
target = extract_target.(samples[1:5_000])
target = reduce(catobs, target)[:cuisine].data

# 	create the model according to the data
m = reflectinmodel(sch, extract_data,
	layer -> Dense(layer,20,relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, size(target, 1))),
)

@non_differentiable getobs(x::DataSubset{<:ProductNode})

#  train
opt = Flux.Optimise.ADAM()
loss(x, y) = Flux.logitcrossentropy(m(x).data, y)
loss(x::DataSubset, y) = loss(getobs(x), y)
loss(xy::Tuple) = loss(xy...)
valdata = data[1:1_000],target[:,1:1_000]
data, target = data[1_001:5_000], target[:,1001:5_000]
# for less recourse-chungry training, we use only part of data for trainng, but it is advised to used all, as i following line:
# data, target = data[1001:nobs(data)], target[:,1001:size(target,2)]

cb = () -> println("accuracy = ",mean(Flux.onecold(m(valdata[1]).data) .== Flux.onecold(valdata[2])))
ps = Flux.params(m)
mean(Flux.onecold(m(data).data) .== Flux.onecold(target))

iterations = 20
minibatchsize = 4000
minibatches = RandomBatches((data, target), size = minibatchsize, count = iterations)

@info "testing the gradient"
loss(first(minibatches))
gs = gradient(() -> loss(first(minibatches)), ps)
Flux.Optimise.update!(opt, ps, gs)

# feel free to train for longer period of time, this example is learns only 20 iterations, so it runs fast
loss(first(minibatches))
gs = gradient(() -> loss(first(minibatches)), ps)
Flux.Optimise.train!(loss, ps, minibatches, opt, cb = Flux.throttle(cb, 2))

#calculate the accuracy
mean(Flux.onecold(m(data).data) .== Flux.onecold(target))
