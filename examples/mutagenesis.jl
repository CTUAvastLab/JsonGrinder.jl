using MLDatasets, JsonGrinder, Flux, Mill, MLDataPattern, Statistics, ChainRulesCore

###############################################################
# start by loading all samples
###############################################################
train_x, train_y = MLDatasets.Mutagenesis.traindata();
test_x, test_y = MLDatasets.Mutagenesis.testdata();

minibatchsize = 100
iterations = 5_000
neurons = 20 		# neurons per layer

#####
#  Create the schema and extractor from training data
#####
sch = JsonGrinder.schema(train_x)
extractor = suggestextractor(sch)

#####
#  Convert samples to Mill structure and extract targets
#####
train_data = extractor.(train_x)
test_data = extractor.(test_x)
labelnames = unique(train_y)

@show train_data[1]
#####
#  Create the model
#####
model = reflectinmodel(sch, extractor,
	layer -> Dense(layer, neurons, relu),
	bag -> SegmentedMeanMax(bag),
	fsm = Dict("" => layer -> Dense(layer, length(labelnames))),
)

#####
#  Train the model
#####

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

###############################################################
#  Classify test set
###############################################################

probs = softmax(inference(test_data))
o = Flux.onecold(probs)
pred_classes = labelnames[o]

print(mean(pred_classes .== test_y))
# we see the accuracy is around 79% on test set

#predicted classes for test set
print(pred_classes)
#gt classes for test set
print(test_y)
# probabilities for test set
print(probs)
