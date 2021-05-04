using Flux, MLDataPattern, Mill, JsonGrinder, JSON, Statistics, IterTools, ThreadTools
using JsonGrinder: suggestextractor, ExtractDict
using Mill: reflectinmodel
using StatsBase: sample

###############################################################
# start by loading all samples
###############################################################
samples = Vector{Dict}(open(JSON.parse, "data/mutagenesis/data.json"))

JSON.print(samples[3],2)

metadata = open(JSON.parse, "data/mutagenesis/meta.json")
labelkey = metadata["label"]
test_num = metadata["test_samples"]
minibatchsize = 100
iterations = 5_000
neurons = 20 		# neurons per layer

targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)

train_indices = 1:length(samples)-test_num
test_indices = length(samples)-test_num+1:length(samples)

#####
#  Create the schema and extractor
#####
sch = JsonGrinder.schema(samples)
extractor = suggestextractor(sch)

#####
#  Convert samples to Mill structure and extract targets
#####
data = tmap(extractor, samples)
labelnames = unique(targets)

#####
#  Create the model
#####
model = reflectinmodel(sch, extractor,
	k -> Dense(k, neurons, relu),
	d -> meanmax_aggregation(d),
	fsm = Dict("" => k -> Dense(k, length(labelnames))),
)

#####
#  Train the model
#####
function minibatch()
	idx = sample(1:length(data[train_indices]), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(labelnames[Flux.onecold(model(x).data)] .== y)

trainset = reduce(catobs, data[train_indices])
testset = reduce(catobs, data[test_indices])

cb = () -> begin
	train_acc = accuracy(trainset, targets[train_indices])
	test_acc = accuracy(testset, targets[test_indices])
	println("accuracy: train = $train_acc, test = $test_acc")
end
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))

###############################################################
#  Classify test set
###############################################################

probs = softmax(model(testset).data)
o = Flux.onecold(probs)
pred_classes = labelnames[o]

print(mean(pred_classes .== targets[test_indices]))
# we see the accuracy is around 79% on test set

#predicted classes for test set
print(pred_classes)
#gt classes for test set
print(targets[test_indices])
# probabilities for test set
print(probs)
