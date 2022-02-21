#src this layout is heavily inspired by how examples in https://github.com/Ferrite-FEM/Ferrite.jl are generated

# # Mutagenesis Example
# Following example demonstrates learning to [predict the mutagenicity on Salmonella typhimurium](https://relational.fit.cvut.cz/dataset/Mutagenesis) (dataset is stored in json format [in MLDatasets.jl](https://juliaml.github.io/MLDatasets.jl/stable/datasets/Mutagenesis/) for your convenience).

#md # !!! tip
#md #     This example is also available as a Jupyter notebook, feel free to run it yourself:
#md #     [`mutagenesis.ipynb`](@__NBVIEWER_ROOT_URL__/examples/mutagenesis.ipynb)

#nb # We start by installing JsonGrinder and few other packages we need for the example.
#nb # Julia Ecosystem follows philosophy of many small single-purpose composable packages
#nb # which may be different from e.g. python where we usually use fewer larger packages.
#nb using Pkg
#nb pkg"add JsonGrinder#master MLDatasets Flux Mill#master MLDataPattern Statistics"

# Here we include libraries all necessary libraries
using JsonGrinder, MLDatasets, Flux, Mill, MLDataPattern, Statistics

# Here we load all samples.
train_x, train_y = MLDatasets.Mutagenesis.traindata();
test_x, test_y = MLDatasets.Mutagenesis.testdata();

# We define some basic parameters for the construction and training of the neural network.
# Minibatch size is self-explanatory, iterations is number of iterations of gradient descent
# Neurons is number of neurons in hidden layers for each version of part of the neural network.
minibatchsize = 100
iterations = 5_000
neurons = 20

#md # This is the **step 1** of the workflow
#md #
# We create the schema of the training data, which is the first important step in using the JsonGrinder.
# This computes both the structure (also known as JSON schema) and histogram of occurrences of individual values in the training data.
sch = JsonGrinder.schema(train_x)

#md # This is the **step 2** of the workflow
#md #
# Then we use it to create the extractor converting jsons to Mill structures.
# The `suggestextractor` is executed below with default setting, but it allows you heavy customization.
# We also prepare list of classes. This classification problem is two-class, but we want to infer it from labels.
extractor = suggestextractor(sch)
labelnames = unique(train_y)

#md # This is the **step 3** of the workflow, we create the model using the schema and extractor
#md #
# # Create the model
# We create the model reflecting structure of the data
model = reflectinmodel(sch, extractor,
	layer -> Dense(layer, neurons, relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, length(labelnames))),
)
# this allows us to create model flexibly, without the need to hardcode individual layers.
# Individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/dev/manual/reflectin/#Model-Reflection). But briefly: for every numeric array in the sample, model will create a dense layer with `neurons` neurons (20 in this example). For every vector of observations (called bag in Multiple Instance Learning terminology), it will create aggregation function which will take mean, maximum of feature vectors and concatenate them. The `fsm` keyword argument basically says that on the end of the NN, as a last layer, we want 2 neurons `length(labelnames)` in the output layer, not 20 as in the intermediate layers.

#md # This is the **step 4** of the workflow, we call the extractor on each sample
#md #
# We convert jsons to mill data samples and prepare list of classes. This classification problem is two-class, but we want to infer it from labels.
# The extractor is callable, so we can pass it vector of samples to obtain vector of structures with extracted features.
train_data = extractor.(train_x)
test_data = extractor.(test_x)

#md # This is the **step 5** of the workflow, we train the model
#md #
# # Train the model
# Then, we define few handy functions and a loss function, which is categorical crossentropy in our case.

loss(x,y) = Flux.logitcrossentropy(inference(x), Flux.onehotbatch(y, labelnames))
inference(x) = model(x).data
accuracy(x,y) = mean(labelnames[Flux.onecold(inference(x))] .== y)
loss(xy::Tuple) = loss(xy...)

# And we can add a callback which will be printing train and test accuracy during the training
# and then we can start trining
cb = () -> begin
	train_acc = accuracy(train_data, train_y)
	test_acc = accuracy(test_data, test_y)
	println("accuracy: train = $train_acc, test = $test_acc")
end

# Lastly we turn our training data to minibatches, and we can start training
minibatches = RandomBatches((train_data, train_y), size = minibatchsize, count = iterations)
Flux.Optimise.train!(loss, Flux.params(model), minibatches, ADAM(), cb = Flux.throttle(cb, 2))
# We can see the accuracy rising and obtaining over 98% on training set quite quickly, and on test set we get over 70%.

# # Classify test set
# The Last part is inference on test data.
probs = softmax(inference(test_data))
o = Flux.onecold(probs)
pred_classes = labelnames[o]
mean(pred_classes .== test_y)

# `pred_classes` contains the predictions for our test set.
# we see the accuracy is around 75% on test set
# predicted classes for test set
pred_classes
# Ground truth classes for test set
test_y
# probabilities for test set
probs

# We can look at individual samples. For instance, some sample from test set is
test_data[2]

# and the corresponding classification is
pred_classes[2]

# if you want to see the probability distribution, it can be obtained by applying `softmax` to the output of the network.
softmax(model(test_data[2]).data)

# so we can see that the probability that given sample is `mutagenetic` is almost 1.
