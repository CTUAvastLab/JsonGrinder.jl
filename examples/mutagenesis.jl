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
#nb pkg"add JsonGrinder#master MLDatasets Flux Mill Statistics"

# This example is taken from the [CTUAvastLab/JsonGrinderExamples](https://github.com/CTUAvastLab/JsonGrinderExamples/blob/main/mutagenesis/tuned.jl)
# and heavily commented for more clarity.

# Here we include libraries all necessary libraries
using JsonGrinder, Mill, Flux, MLDatasets, Statistics, Random

# we stabilize the seed to obtain same results every run, for pedagogic purposes
Random.seed!(42)

# We define some basic parameters for the construction and training of the neural network.
# Minibatch size is self-explanatory, Neurons is number of neurons in hidden layers for 
# each version of part of the neural network.

neurons = 50
BATCH_SIZE = 50

# Here we load the training samples.
x_train, y_train = MLDatasets.Mutagenesis.traindata();

#md # This is the **step 1** of the workflow
#md #
# We create the schema of the training data, which is the first important step in using the JsonGrinder.
# This computes both the structure (also known as JSON schema) and histogram of occurrences of individual values in the training data.
sch = JsonGrinder.schema(x_train)

#md # This is the **step 2** of the workflow
#md #
# Then we use it to create the extractor converting jsons to Mill structures.
# The `suggestextractor` is executed below with default setting, but it allows you heavy customization.
extractor = suggestextractor(sch)

#md # This is the **step 3** of the workflow, we create the model using the schema and extractor
#md #
# # Create the model
# We create the model reflecting structure of the data
encoder = reflectinmodel(sch, extractor)
# this allows us to create model flexibly, without the need to hardcode individual layers.
# Individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/stable/manual/reflectin/#Model-Reflection).
# But briefly: for every numeric array in the sample, model will create a dense layer with `neurons` neurons (20 in this example).
# For every vector of observations (called bag in Multiple Instance Learning terminology), it will create aggregation function which will take mean, maximum of feature vectors and concatenate them.
# The `fsm` keyword argument basically says that on the end of the NN, as a last layer, we want 2 neurons `length(labelnames)` in the output layer, not 20 as in the intermediate layers.
# then we add layer with 2 output of the model at the end of the neural network
model = Dense(10, 2) ∘ encoder

#md # This is the **step 4** of the workflow, we call the extractor on each sample
#md #
# We convert jsons to mill data samples and prepare list of classes. This classification problem is two-class, but we want to infer it from labels.
# The extractor is callable, so we can pass it vector of samples to obtain vector of structures with extracted features.
ds_train = extractor.(x_train)

#md # This is the **step 5** of the workflow, we train the model
#md #
# # Train the model
# Then, we define few handy functions and a loss function, which is logit binary crossentropy in our case.
# Here we add +1 to labels, because the labels are {0,1} and idxmax of the model output is in the {1,2} range.
loss(ds, y) = Flux.Losses.logitbinarycrossentropy(model(ds), Flux.onehotbatch(y .+ 1, 1:2))
accuracy(ds, y) = mean(Flux.onecold(model(ds)) .== y .+ 1)

# We prepare the optimizer.
opt = AdaBelief()
ps = Flux.params(model)

# Lastly we turn our training data to minibatches, and we can start training
data_loader = Flux.Data.DataLoader((ds_train, y_train), batchsize=BATCH_SIZE, shuffle=true)
# We can see the accuracy rising and obtaining over 70% quite quickly
Flux.@epochs 3 begin
    Flux.Optimise.train!(loss, ps, data_loader, opt)
    @show accuracy(ds_train, y_train)
end

# # Classify test set
# The Last part is inference and evaluation on test data.
x_test, y_test = MLDatasets.Mutagenesis.testdata();
ds_test = extractor.(x_test)
@show accuracy(ds_test, y_test)

probs = softmax(model(ds_test))
o = Flux.onecold(probs)
mean(o .== y_test .+ 1)

# `pred_classes` contains the predictions for our test set.
# we see the accuracy is around 75% on test set
# predicted classes for test set
o
# Ground truth classes for test set
y_test .+ 1
# probabilities for test set
probs

# We can look at individual samples. For instance, some sample from test set is
ds_test[2]

# and the corresponding classification is
y_test[2] + 1

# if you want to see the probability distribution, it can be obtained by applying `softmax` to the output of the network.
softmax(model(ds_test[2]))

# so we can see that the probability that given sample is `mutagenetic` is > 60%.
