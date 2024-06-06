```@setup hyperopt
using JsonGrinder
```

# Integrating with Hyperopt.jl

Below, we show a simple example of how to use
[`Hyperopt.jl`](https://github.com/baggepinnen/Hyperopt.jl) to perform hyperparameter optimization
for us.

!!! ukn "Prerequisites"
    We reuse a lot of code from the [Recipe Ingredients](@ref) example and recommend the reader to get
    familiar with it.

    The data are accessible
    [here](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/docs/src/examples/recipes).

We import all libraries, split the dataset into training, testing, and validation sets, prepare
one-hot-encoded labels, infer a [`Schema`](@ref), define an [`Extractor`](@ref), and extract all
documents:

```@example hyperopt
using Mill, Flux, OneHotArrays, JSON, Statistics

using Random; Random.seed!(42);

nothing # hide
```

```@example hyperopt
dataset = JSON.parse.(readlines("../examples/recipes/recipes.jsonl"))
shuffle!(dataset)
jss_train, jss_val, jss_test = dataset[1:1500], dataset[1501:2000], dataset[2001:end]

y_train = getindex.(jss_train, "cuisine")
y_val = getindex.(jss_val, "cuisine")
y_test = getindex.(jss_test, "cuisine")
classes = unique(y_train)
y_train_oh = onehotbatch(y_train, classes)

sch = schema(jss_train)
delete!(sch.children, :cuisine)
delete!(sch.children, :id)

e = suggestextractor(sch)

x_train = extract(e, jss_train)
x_val = extract(e, jss_val)
x_test = extract(e, jss_test)

pred(m, x) = softmax(m(x))
accuracy(p, y) = mean(onecold(p, classes) .== y)
loss(m, x, y) = Flux.Losses.logitbinarycrossentropy(m(x), y)

nothing # hide
```

Now we define a function `train_model`, which given a set of hyperparameters trains a new model. We
will use the following hyperparameters:

- `epochs`: number of epochs in training
- `batchsize`: number of samples in a single minibatch
- `d`: "inner" dimensionality of `Dense` layers in the models
- `layers`: number of layers to use in each node in the model
- `activation`: activation function

```@example hyperopt
function train_model(epochs, batchsize, d, layers, activation)
    layer_builder = in_d -> Chain(
        Dense(in_d, d, activation), [Dense(d, d, activation) for _ in 1:layers-1]...
    )
    encoder = reflectinmodel(sch, e, layer_builder)
    model = Dense(d, length(classes)) ∘ encoder

    opt_state = Flux.setup(Flux.Optimise.Adam(), model);
    minibatch_iterator = Flux.DataLoader((x_train, y_train_oh); batchsize, shuffle=true);

    for i in 1:epochs
        Flux.train!(loss, model, minibatch_iterator, opt_state)
    end

    model
end

nothing # hide
```

```@repl hyperopt
train_model(2, 20, 10, 2, identity)
```

Now we can run the hyperparameter search. In this simple example, we will use `RandomSampler`, and
in each iteration we will train a new model with `train_model`. The optimization criterion is the
accuracy on the validation set.

```@example hyperopt
using Hyperopt
```

```@repl hyperopt
ho = @hyperopt for i = 50,
            sampler = RandomSampler(),
            epochs = [3, 5, 10],
            batchsize = [16, 32, 64],
            d = [16, 32, 64],
            layers = [1, 2, 3],
            activation = [identity, relu, tanh]
    model = train_model(epochs, batchsize, d, layers, activation)
    accuracy(pred(model, x_val), y_val)
end
```

We have arrived at the following solution:

```@repl hyperopt
printmax(ho)
```

Finally, we test the solution on the testing data:

```@repl hyperopt
final_model = train_model(ho.maximizer...);
accuracy(pred(final_model, x_test), y_test)
```

This concludes a very simple example of how to integrate
[`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) with
[`Hyperopt.jl`](https://github.com/baggepinnen/Hyperopt.jl). Note that we could and should go
further and experiment not only with the hyperparameters presented here, but also with the
definition of the schema and/or the extractor, which can also have significant impact on the
results.
