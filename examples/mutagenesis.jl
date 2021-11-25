#src this layout is heavily inspired by how examples in https://github.com/Ferrite-FEM/Ferrite.jl are generated

# # Mutagenesis Example
# Following example demonstrates learning to [predict the mutagenicity on Salmonella typhimurium](https://relational.fit.cvut.cz/dataset/Mutagenesis) (dataset is stored in json format [in MLDatasets.jl](https://juliaml.github.io/MLDatasets.jl/stable/datasets/Mutagenesis/) for your convenience).

#md # !!! tip
#md #     This example is also available as a Jupyter notebook, feel free to run it yourself:
#md #     [`mutagenesis.ipynb`](@__NBVIEWER_ROOT_URL__/examples/mutagenesis.ipynb)

# Here we include libraries all necessary libraries
using MLDatasets, JsonGrinder, Flux, Mill, MLDataPattern, Statistics, ChainRulesCore

# Here we load all samples.
train_x, train_y = MLDatasets.Mutagenesis.traindata();
test_x, test_y = MLDatasets.Mutagenesis.testdata();

# We define some basic parameters for the construction and training of the neural network.
# Minibatch size is self-explanatory, iterations is number of iterations of gradient descent
# Neurons is number of neurons in hidden layers for each version of part of the neural network.
minibatchsize = 100
iterations = 5_000
neurons = 20

# We create the schema of the training data, which is the first important step in using the JsonGrinder.
# This computes both the structure (also known as JSON schema) and histogram of occurrences of individual values in the training data.
sch = JsonGrinder.schema(train_x)
extractor = suggestextractor(sch)

# Then we use it to create the extractor converting jsons to Mill structures.
# The `suggestextractor` is executed below with default setting, but it allows you heavy customization.
train_data = extractor.(train_x)
test_data = extractor.(test_x)
labelnames = unique(train_y)

@show train_data[1]

# # Create the model
model = reflectinmodel(sch, extractor,
	layer -> Dense(layer, neurons, relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, length(labelnames))),
)

# # Train the model
# let's define loss and some helper functions
loss(x,y) = Flux.logitcrossentropy(inference(x), Flux.onehotbatch(y, labelnames))
inference(x::AbstractMillNode) = model(x).data
inference(x::AbstractVector{<:AbstractMillNode}) = inference(reduce(catobs, x))
accuracy(x,y) = mean(labelnames[Flux.onecold(inference(x))] .== y)
loss(xy::Tuple) = loss(xy...)
@non_differentiable Base.reduce(catobs, x::AbstractVector{<:AbstractMillNode})
cb = () -> begin
	train_acc = accuracy(train_data, train_y)
	test_acc = accuracy(test_data, test_y)
	println("accuracy: train = $train_acc, test = $test_acc")
end

# create minibatches
minibatches = RandomBatches((train_data, train_y), size = minibatchsize, count = iterations)
Flux.Optimise.train!(loss, Flux.params(model), minibatches, ADAM(), cb = Flux.throttle(cb, 2))

# # Classify test set
probs = softmax(inference(test_data))
o = Flux.onecold(probs)
pred_classes = labelnames[o]
mean(pred_classes .== test_y)

# we see the accuracy is around 75% on test set
# predicted classes for test set
pred_classes
# Ground truth classes for test set
test_y
# probabilities for test set
probs
