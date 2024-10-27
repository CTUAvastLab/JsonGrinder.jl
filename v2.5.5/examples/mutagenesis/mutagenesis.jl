using JsonGrinder, Mill, Flux, JSON, MLUtils, Statistics

using Random; Random.seed!(42);

dataset = JSON.parsefile("mutagenesis.json");
jss_train, jss_test = dataset[1:100], dataset[101:end];

jss_train[1]

y_train = getindex.(jss_train, "mutagenic");
y_test = getindex.(jss_test, "mutagenic");
y_train

sch = schema(jss_train)

delete!(sch, :mutagenic);
sch

e = suggestextractor(sch)

x_single = e(jss_train[1])

x_batch = reduce(catobs, e.(jss_train[1:10]))

x_train = extract(e, jss_train);
x_test = extract(e, jss_test);
x_train

encoder = reflectinmodel(sch, e)

model = vec ∘ Dense(10, 1) ∘ encoder

pred(m, x) = σ.(m(x))
loss(m, x, y) = Flux.Losses.logitbinarycrossentropy(m(x), y);
opt_state = Flux.setup(Flux.Optimise.Descent(), model);
minibatch_iterator = Flux.DataLoader((x_train, y_train), batchsize=32, shuffle=true);

accuracy(p, y) = mean((p .> 0.5) .== y)
for i in 1:10
    Flux.train!(loss, model, minibatch_iterator, opt_state)
    @info "Epoch $i" accuracy=accuracy(pred(model, x_train), y_train)
end

accuracy(pred(model, x_test), y_test)
