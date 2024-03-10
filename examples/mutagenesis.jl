#src this layout is heavily inspired by how examples in https://github.com/Ferrite-FEM/Ferrite.jl are generated

# # Mutagenesis Example
# The following example demonstrates learning to [predict the mutagenicity on Salmonella typhimurium](https://relational.fit.cvut.cz/dataset/Mutagenesis) (dataset is stored in JSON format [in MLDatasets.jl](https://juliaml.github.io/MLDatasets.jl/stable/datasets/Mutagenesis/) for your convenience).

#md # !!! tip
#md #     This example is also available as a Jupyter notebook, feel free to run it yourself:
#md #     [`mutagenesis.ipynb`](@__NBVIEWER_ROOT_URL__/examples/mutagenesis.ipynb)

#nb # We start by installing JsonGrinder and few other packages we need for the example.
#nb # Julia Ecosystem follows philosophy of many small single-purpose composable packages
#nb # which may be different from e.g. python where we usually use fewer larger packages.
#nb using Pkg
#nb pkg"add JsonGrinder#master Mill Flux MLDatasets Statistics Random OneHotArrays"

# This example is taken from the [CTUAvastLab/JsonGrinderExamples](https://github.com/CTUAvastLab/JsonGrinderExamples/blob/main/mutagenesis/tuned.jl)
# and heavily commented for more clarity.

# Here we include all necessary libraries:
using JsonGrinder, Mill, Flux, MLDatasets, Statistics, Random, OneHotArrays

# We stabilize the seed to obtain same results every run, for pedagogic purposes:
Random.seed!(42)

# We define the minibatch size:
BATCH_SIZE = 10

# Here we load the training samples:
dataset_train = MLDatasets.Mutagenesis(split=:train);
x_train = dataset_train.features
y_train = dataset_train.targets

#md # ### Step 1
#md #
# We create the schema of the training data, which is the first important step in using the JsonGrinder.
# This computes both the structure (also known as JSON schema) and histogram of occurrences of individual values in the training data.
sch = JsonGrinder.schema(x_train)

#md # ### Step 2
#md #
# Then we use it to create the extractor converting JSONs to Mill structures.
# The `suggestextractor` is executed below with default setting, but it also allows you heavy customization.
extractor = suggestextractor(sch)

#md # ### Step 3: Create the model using the schema and extractor
#md #
# We create the model reflecting structure of the data:
encoder = reflectinmodel(sch, extractor, d -> Dense(d, 10, relu))
# This allows us to create model flexibly, without the need to hardcode individual layers.
#
# Individual arguments of `reflectinmodel` are explained in [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/stable/manual/reflectin/#Model-Reflection).
# But briefly: for every numeric array in the sample, model will create a dense layer with `neurons` neurons (20 in this example).
# For every vector of observations (called bag in Multiple Instance Learning terminology), it will create aggregation function which will take mean, maximum of feature vectors and concatenate them.
# The `fsm` keyword argument basically says that on the end of the NN, as a last layer, we want 2 neurons `length(labelnames)` in the output layer, not 20 as in the intermediate layers.
# Then we add layer with 2 output of the model at the end of the neural network
model = Dense(10, 2) ∘ encoder

#md # ### Step 4: Call the extractor on each sample.
# We convert JSONs to Mill data samples and prepare list of classes. This classification problem is two-class, but we want to infer it from labels.
# The extractor is callable, so we can pass it vector of samples to obtain vector of structures with extracted features.
ds_train = extractor.(x_train)

#md # ### Step 5: Train the model
#md #
# Then, we define a few handy functions and a loss function, which is logit binary crossentropy in our case.
# Here we add +1 to labels, because the labels are {0,1} and idxmax of the model output is in the {1,2} range.
loss(ds, y) = Flux.Losses.logitbinarycrossentropy(model(ds), OneHotArrays.onehotbatch(y .+ 1, 1:2))
accuracy(ds, y) = mean(Flux.onecold(model(ds)) .== y .+ 1)

# We prepare the optimizer:
opt = AdaBelief()
ps = Flux.params(model)

# Lastly we turn our training data to minibatches, and we can start training:
data_loader = Flux.DataLoader((ds_train, y_train), batchsize=BATCH_SIZE, shuffle=true)

# We can see the accuracy rising and obtaining over 80% quite quickly:
for i in 1:10
    @info "Epoch $i"
    Flux.Optimise.train!(loss, ps, data_loader, opt)
    @show accuracy(ds_train, y_train)
end

# ## Classify test set
# The last part is inference and evaluation on test data.
dataset_test = MLDatasets.Mutagenesis(split=:test);
x_test = dataset_test.features
y_test = dataset_test.targets
ds_test = extractor.(x_test)

# We see that the test set accuracy is also over 80%
@show accuracy(ds_test, y_test)

probs = softmax(model(ds_test))
o = Flux.onecold(probs)
mean(o .== y_test .+ 1)

# `pred_classes` contains the predictions for our test set.
# We see the accuracy is around 75% on predicted classes for test set
o
# Ground truth classes for test set:
y_test .+ 1
# Probabilities for test set:
probs

# We can look at individual samples. For instance, some sample from test set is:
ds_test[2]

# and the corresponding classification is:
y_test[2] + 1

# If you want to see the probability distribution, it can be obtained by applying `softmax` to the output of the network:
softmax(model(ds_test[2]))

# So we can see that the probability that given sample belongs to the first class is > 60%.
