using JsonGrinder, Mill, Flux, OneHotArrays, JSON3, MLUtils, Statistics

using Random; Random.seed!(42);

dataset = JSON3.read.(readlines("recipes.jsonl"));
shuffle!(dataset);
jss_train, jss_test = dataset[1:2000], dataset[2001:end];
jss_train[1]

y_train = getindex.(jss_train, "cuisine");
y_test = getindex.(jss_test, "cuisine");
y_train

classes = unique(y_train)

y_train_oh = onehotbatch(y_train, classes)

sch = schema(jss_train)

delete!(sch.children, :cuisine);
delete!(sch.children, :id);
sch

jss_train = getindex.(jss_train, "ingredients");
jss_test = getindex.(jss_test, "ingredients");
jss_train[1]

sch[:ingredients]

sch = schema(jss_train)

e = suggestextractor(sch)

extract(e, jss_train)

encoder = reflectinmodel(sch, e, d -> Dense(d, 40, relu), d -> SegmentedMeanMaxLSE(d) |> BagCount)
model = Dense(40, length(classes)) ∘ encoder

pred(m, x) = softmax(m(x))
opt_state = Flux.setup(Flux.Optimise.Adam(), model);
minibatch_iterator = Flux.DataLoader((jss_train, y_train_oh), batchsize=32, shuffle=true);
accuracy(p, y) = mean(onecold(p, classes) .== y)

for i in 1:20
    Flux.train!(model, minibatch_iterator, opt_state) do m, jss, y
        x = Flux.@ignore_derivatives extract(e, jss)
        Flux.Losses.logitcrossentropy(m(x), y)
    end
    @info "Epoch $i" accuracy=accuracy(pred(model, extract(e, jss_train)), y_train)
end

accuracy(model(extract(e, jss_test)), y_test)
