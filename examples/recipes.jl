# # Recipe Ingredients Example
# Following example demonstrates prediction of cuisine from set of ingredients.

# ## A gentle introduction to creation of neural networks reflexing structure of JSON documents 

# This notebook serves as an introduction to `Mill` and `JsonGrinder` libraries. 
# The former provides support for Multi-instance learning problems, their cascades, and their Cartesian product ([see the paper](https://arxiv.org/abs/2105.09107) for theoretical explanation). 
# The latter `JsonGrinder` simplifies processing of JSON documents. It allows to infer schema of JSON documents from which it suggests an extractor to convert JSON document to a `Mill` structure.
# `JsonGrinder` defines basic set of "extractors" converting values of keys to numeric representation (matrices) or to convert them to corresponding structures in `Mill`. Naturally, this set of extractors can be extended.
# 
# Below, the intended workflow is demonstrated on a simple problem of guessing type of a cuisine from a list of ingrediences. 
# The whole dataset and problem description can be found [on this Kaggle page](https://www.kaggle.com/kaggle/recipe-ingredients-dataset/home).
# Note that the goal is not to achieve state of the art, but to demonstrate the workflow.

#md # !!! tip
#md #     This example is also available as a Jupyter notebook:
#md #     [`recipes.ipynb`](@__NBVIEWER_ROOT_URL__/examples/recipes.ipynb)

# todo: dodělat, domigrovat z ipynb a ten pak smazat
# **Caution**
# To decrease the computational load, we keep locally in the repo only a subset of the whole dataset (39774), size of the minibatch, and size of the validation data. 
# Of course these numbers are useless in practice, and therefore the resulting accuracy is poor. 
# Using all samples (666920), setting minibatch size to 100, and leaving 1000 samples for validation / testing gives you accuracy 0.74 on validation data.
# 
#nb # We start by installing JsonGrinder and few other packages we need for the example.
#nb # Julia Ecosystem follows philosophy of many small single-purpose composable packages
#nb # which may be different from e.g. python where we usually use fewer larger packages.
#nb using Pkg
#nb pkg"add JsonGrinder#master Flux Mill#master MLDataPattern Statistics ChainRulesCore JSON"

using JsonGrinder, Flux, Mill, MLDataPattern, Statistics, ChainRulesCore, JSON

# start by loading all samples
#src magic for resolving paths
data_file = "data/recipes.json" #src
data_file = "../../../data/recipes.json" #nb
data_file = "data/recipes.json" #md
data_file = "data/recipes.json" #jl
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

# # Create the model
m = reflectinmodel(sch, extract_data,
	layer -> Dense(layer,20,relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, size(target, 1))),
)

@non_differentiable getobs(x::DataSubset{<:ProductNode})

# # Train the model
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

# calculate the accuracy
mean(Flux.onecold(m(data).data) .== Flux.onecold(target))
