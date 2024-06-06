```@setup recipes
using Pkg
old_path = Pkg.project().path
Pkg.activate(pwd())
Pkg.instantiate()
```
```@meta
EditURL = "recipes_literate.jl"
```

# Recipe Ingredients

The following simple example shows how to train a hierarchical model for predicting the
type of cuisine from a set of used ingredients.

!!! ukn "Jupyter notebook"
    This example is also available as a [Jupyter notebook](<unknown>/examples/recipes/recipes.ipynb)
    and the environment and the data are accessible [here](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/docs/src/examples/recipes).

!!! ukn "Recommended reading"
    We recommend to first read the [Mutagenesis](@ref) example, which introduces core
    concepts. This example shows application on another dataset and integration with
    [`JSON3.jl`](https://github.com/quinnj/JSON3.jl).

We load all dependencies and fix the seed:

````@example recipes
using JsonGrinder, Mill, Flux, OneHotArrays, JSON3, MLUtils, Statistics

using Random; Random.seed!(42);
nothing #hide
````

The full dataset and the problem description can be also found on [Kaggle](https://www.kaggle.com/kaggle/recipe-ingredients-dataset/home), but for demonstration purposes we load only its small subset:

````@example recipes
dataset = JSON3.read.(readlines("recipes.jsonl"));
shuffle!(dataset);
jss_train, jss_test = dataset[1:2000], dataset[2001:end];
jss_train[1]
````

Labels are stored in the `"cuisine"` field:

````@example recipes
y_train = getindex.(jss_train, "cuisine");
y_test = getindex.(jss_test, "cuisine");
y_train
````

In this example we have more classes than two, so we also encode all training labels into one-hot vectors:

````@example recipes
classes = unique(y_train)
````

````@example recipes
y_train_oh = onehotbatch(y_train, classes)
````

Now we create a schema:

````@example recipes
sch = schema(jss_train)
````

!!! ukn "Function as first argument"
    Function [`schema`](@ref) accepts an optional argument, a function first mapping all elements of
    an input array. We could thus reduce the schema creation into a single command
    `schema(JSON3.read, readlines("recipes.jsonl"))`.

From the schema, we will delete the `"cuisine"` key storing the label, and also the `"id"` key,
which is just the id of the sample, which is not useful in training:

````@example recipes
delete!(sch.children, :cuisine);
delete!(sch.children, :id);
sch
````

We can see that only a single key `"ingredients"` is left. We can thus just take its content:

````@example recipes
jss_train = getindex.(jss_train, "ingredients");
jss_test = getindex.(jss_test, "ingredients");
jss_train[1]
````

We can infer the schema again, or just take a subtree of the original schema

We can just take the only subtree of the original schema `sch`:

````@example recipes
sch[:ingredients]
````

Or infer it once again, this time `jss_train` is not a `Vector` of `Dict`s, but a `Vector` of `Vector`s:

````@example recipes
sch = schema(jss_train)
````

Next step is to create an extractor:

````@example recipes
e = suggestextractor(sch)
````

If we have sufficient memory, we can extract all documents before training like in the
[Mutagenesis](@ref) example:

````@example recipes
extract(e, jss_train)
````

However, in this example we want to show how to extract online in the training loop.

We continue with the model definition, making use of some of the
[`Mill.reflectinmodel`](@ref) features.
We continue with the model definition, making use of some of the

````@example recipes
encoder = reflectinmodel(sch, e, d -> Dense(d, 40, relu), d -> SegmentedMeanMaxLSE(d) |> BagCount)
model = Dense(40, length(classes)) ∘ encoder
````

We define important components for the training:

````@example recipes
pred(m, x) = softmax(m(x))
opt_state = Flux.setup(Flux.Optimise.Adam(), model);
minibatch_iterator = Flux.DataLoader((jss_train, y_train_oh), batchsize=32, shuffle=true);
accuracy(p, y) = mean(onecold(p, classes) .== y)
````

And run the training:

````@example recipes
for i in 1:20
    Flux.train!(model, minibatch_iterator, opt_state) do m, jss, y
        x = Flux.@ignore_derivatives extract(e, jss)
        Flux.Losses.logitcrossentropy(m(x), y)
    end
    @info "Epoch $i" accuracy=accuracy(pred(model, extract(e, jss_train)), y_train)
end
````

Finally, let's measure the testing accuracy. In this case, the classifier is overfitted:

````@example recipes
accuracy(model(extract(e, jss_test)), y_test)
````

```@setup recipes
Pkg.activate(old_path)
```
