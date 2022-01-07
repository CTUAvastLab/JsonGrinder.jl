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
# To reduc, we keep locally in the repo only a subset of the whole dataset (`39774`).
# To decrease the computational load we use only `5000` samples, size of the validation data = `100`, size of the minibatch `10` and train for 20 iterations.
# Of course these numbers are useless in practice, and therefore the resulting accuracy is poor. 
# Using all samples (`39774`), leaving `4774` samples for validation, setting minibatch size to `1000`, and training for `1000` iterations gives you accuracy 0.73 on validation data.

n_samples, n_val, minibatchsize, iterations = 5_000, 100, 10, 20
#n_samples, n_val, minibatchsize, iterations = 39_774, 4_774, 1_000, 1_000

#nb # We start by installing JsonGrinder and few other packages we need for the example.
#nb # Julia Ecosystem follows philosophy of many small single-purpose composable packages
#nb # which may be different from e.g. python where we usually use fewer larger packages.
#nb using Pkg
#nb pkg"add JsonGrinder#master Flux Mill#master MLDataPattern Statistics ChainRulesCore JSON"

# Let's start by imorting all libraries we will need.
using JsonGrinder, Flux, Mill, MLDataPattern, Statistics, ChainRulesCore, JSON

# ### Preparing data
# After importing libraties we load all samples. Of course we can affort it only for small datasets, but 
# for the sake of simplicity we keep whole dataset in memory, while recognizing this is usually not 
# feasible in real-world scenations.
# Data are stored in a format "json per line". 
# This means that each sample is one JSON document stored in each line. 
# These samples are loaded and parsed to an array. On the end, one sample is printed to show, how data looks like.

#src magic for resolving paths
data_file = "data/recipes.json" #src
data_file = "../../../data/recipes.json" #nb
data_file = "data/recipes.json" #md
data_file = "data/recipes.json" #jl
samples = open(data_file,"r") do fid
	Vector{Dict}(JSON.parse(read(fid, String)))
end
JSON.print(samples[1],2)

# Now we create schema of the JSON.
# Unline XML or ProtoBuf, JSON documents do not have any schema by default. 
# Threfore *JsonGrinder* attempts to infer the schema, which is then used to recommend the extractor.
sch = JsonGrinder.schema(samples[1:n_samples])

# ID is deleted from the schema (keys not in the schema are not 
# reflected into extractor and hence not propagated into dataset).
delete!(sch.childs,:id)

# From the schema, we can create the extractor.
extractor = suggestextractor(sch)

# Since cuisine is a class label we want to predict, 
# the extractor needs to be split into two. 
# `extract_data` will extract the sample and `extract_target` will extract the target.
extract_data = ExtractDict(deepcopy(extractor.dict))
extract_target = ExtractDict(deepcopy(extractor.dict))
delete!(extract_target.dict, :ingredients)
delete!(extract_data.dict, :cuisine)

# Now, `extract_data` is a functor extracting samples and `extract_target` extract targets. Let's first demonstrate extractor of datas.
extract_data(samples[1])
extract_target(samples[1])[:cuisine]

# Now we use these extractors to convert JSONs to Mill structures which behave as our datasets.
data = extract_data.(samples[1:n_samples])
data = reduce(catobs, data)

# Now the `data` variable is a Mill structure containing `n_samples` obs (observations). 
# Each observation there is a sample from the dataset.
# The root of this tree-like structure is ProductNode containing `ingredients` key, reflecting the 
# same name as samples have in training data, and then we have `BagNode` of `ArrayNode` of `OneHotArray`, 
# which is how the ingredients are represented. Each sample has set of ingredients, which are set of words, 
# `e.g. ["black","olives"]`., where each ingredient is encoded into one-hot vector of dimension 3477 (for the 5000 samples, it's larger if we use whole dataset).
# And we do the same with targets, the extractor converts them to one-hot encoded matrix.
target = extract_target.(samples[1:n_samples])
target = reduce(catobs, target)[:cuisine].data
# We see that target is `21x5000` One-hot matrix in case of 5000 samples. There are 21 cuisines which are the prediction targets.

# ### Defining the model reflecting the structure of data
# 
# Since manually creating a model reflecting the structure can be tedious, Mill support a semi-automated procedure. 
# The function `reflectinmodel` takes as an input data sample and function, which for a given input dimension provides a feed-forward network. 
# In the example below, the function creates a feed forward network with a single fully-connected layer with twenty neurons and relu nonlinearinty. 
# The structure of the network corresponds to the  structure of input data. 
# You can observe that each module dealing with multiple-instance data contains an aggregation layer with element-wise mean and maximum.
m = reflectinmodel(sch, extract_data,
	layer -> Dense(layer,20,relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, size(target, 1))),
)

# ugly hack, hope to get rid of this
@non_differentiable getobs(x::DataSubset{<:ProductNode})

# ### Training the model
# Mill library is compatible with MLDataPattern for manipulating with data (training / testing / minibatchsize preparation) and with Flux. 
# Please, refer to thos two libraries for support.
# Below, data are first split into training and validation sets. 
# Then Adam optimizer for training the model is initialized, and loss function is defined.
# We also define callback which perpetually reports accuracy on validation data during the training.
valdata, valtarget = data[n_samples-n_val:n_samples], target[:,n_samples-n_val:n_samples]
traindata, traintarget = data[1:n_samples-n_val], target[:,1:n_samples-n_val]
opt = Flux.Optimise.ADAM()
loss(x, y) = Flux.logitcrossentropy(m(x).data, y)
loss(x::DataSubset, y) = loss(getobs(x), y)
loss(xy::Tuple) = loss(xy...)
cb = () -> println("accuracy = ",mean(Flux.onecold(m(valdata).data) .== Flux.onecold(valtarget)))
# Here we compute the accuracy.
mean(Flux.onecold(m(traindata).data) .== Flux.onecold(traintarget))
# Here we obtain the trainable parameters from the model
ps = Flux.params(m)

# We use MLDataPattern.RandomBatches to make minibatches from the training data
minibatches = RandomBatches((traindata, traintarget), size = minibatchsize, count = iterations)

# Now we try to compute the loss and perform single step of the gradient descend to see if all works correctly.
loss(first(minibatches))
gs = gradient(() -> loss(first(minibatches)), ps)
Flux.Optimise.update!(opt, ps, gs)

# In this step we finally train the classifier using the loss we have defined above.
Flux.Optimise.train!(loss, ps, minibatches, opt, cb = Flux.throttle(cb, 2))

# ### Reporting accuracy on validation data
# As last steps, we calculate accuracy on training and validation data after the model has been trained.
mean(Flux.onecold(m(traindata).data) .== Flux.onecold(traintarget))
mean(Flux.onecold(m(valdata).data) .== Flux.onecold(valtarget))

# This concludes our example on training the classifier to recogninze cuisine based on ingredients.
