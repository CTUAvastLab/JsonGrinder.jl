# # Mutagenesis

# This example demonstrates how to predict [the mutagenicity on Salmonella typhimurium](https://relational.fel.cvut.cz/dataset/Mutagenesis).

#md # !!! ukn "Jupyter notebook"
#md #     This example is also available as a [Jupyter notebook](@__NBVIEWER_ROOT_URL__/examples/mutagenesis/mutagenesis.ipynb)
#md #     and the environment and the data are accessible [here](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/docs/src/examples/mutagenesis).

#nb # The full environment, the script and the data are accessible [here](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/docs/src/examples/mutagenesis).

#nb # We start by activating the environment and installing required packages
#nb using Pkg
#nb Pkg.activate(pwd())
#nb Pkg.instantiate()
#nb Pkg.status()

# We load all dependencies and fix the seed:
using JsonGrinder, Mill, Flux, JSON, MLUtils, Statistics

using Random; Random.seed!(42);

# ### Loading the data

# we load the dataset (available ), and split it into training and testing set.
dataset = JSON.parsefile("mutagenesis.json");
jss_train, jss_test = dataset[1:100], dataset[101:end];

# `jss_train` and `jss_test` are just lists of parsed JSONs:
jss_train[1]

# We also extract binary labels, which are stored in the `"mutagenic"` key:
y_train = getindex.(jss_train, "mutagenic");
y_test = getindex.(jss_test, "mutagenic");
y_train

# We first create the [`schema`](@ref) of the training data, which is the first important step in using the
# [`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl).
# This infers both the hierarchical structure of the documents and basic statistics of individual values.
sch = schema(jss_train)

# Of course, we have to remove the `"mutagenic"` key from the schema, as we don't want to include it
# in the data:
delete!(sch, :mutagenic);
sch

# Now we create an extractor capable of converting JSONs to [`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures.
# We use function [`suggestextractor`](@ref) with the default settings:
e = suggestextractor(sch)

# We also need to convert JSONs to [`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) data samples.
# Extractor `e` is callable, we can use it to extract one document as follows:
x_single = e(jss_train[1])

# To extract a batch of 10 documents, we can extract individual documents and then `Mill.catobs` them:
x_batch = reduce(catobs, e.(jss_train[1:10]))

# Or we can use a much more efficient [`extract`](@ref) function, which operates on a list of documents:
# Because the dataset is small, we can extract all data at once and keep it in memory:
x_train = extract(e, jss_train);
x_test = extract(e, jss_test);
x_train

# Then we create an encoding model capable of embedding each JSON document into a fixed-size vector.
encoder = reflectinmodel(sch, e)

#md # !!! ukn "Further reading"
#md #     For further details about `reflectinmodel`, see the [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/stable/manual/reflectin/#Model-Reflection).

#nb # For further details about `reflectinmodel`, see the [Mill.jl documentation](https://CTUAvastLab.github.io/Mill.jl/stable/manual/reflectin/#Model-Reflection).

# Finally, we chain the `encoder` with one more dense layer computing the logit of mutagenic probability:
model = vec ∘ Dense(10, 1) ∘ encoder

# We can train the model in the standard [`Flux.jl`](https://fluxml.ai) way. We define the loss
# function, optimizer, and minibatch iterator:
pred(m, x) = σ.(m(x))
loss(m, x, y) = Flux.Losses.logitbinarycrossentropy(m(x), y);
opt_state = Flux.setup(Flux.Optimise.Descent(), model);
minibatch_iterator = Flux.DataLoader((x_train, y_train), batchsize=32, shuffle=true);

# We train for 10 epochs, and after each epoch we report the training accuracy:
accuracy(p, y) = mean((p .> 0.5) .== y)
for i in 1:10
    Flux.train!(loss, model, minibatch_iterator, opt_state)
    @info "Epoch $i" accuracy=accuracy(pred(model, x_train), y_train)
end

# We can compute the accuracy on the testing set now:
accuracy(pred(model, x_test), y_test)
