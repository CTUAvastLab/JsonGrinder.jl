using Flux, MLDataPattern, Mill, JsonGrinder, JSON, Statistics, IterTools
using Serialization
using JsonGrinder: suggestextractor, ExtractDict
using Mill: reflectinmodel

###############################################################
# start by loading all samples
###############################################################
samples = map(readlines("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/dataset/train.json")) do s
	JSON.parse(s)
end;
JSON.print(samples[3],2)

labelkey = "device_class"
minibatchsize = 100
iterations = 10_000
neurons = 20 		# neurons per layer

targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)
foreach(i -> delete!(i, "id"), samples)

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
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, length(labelnames))),
)

#####
#  Train the model
#####
function minibatch()
	idx = sample(1:length(data), minibatchsize, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

accuracy(x,y) = mean(map(xy -> labelnames[argmax(model(xy[1]).data[:])] == xy[2], zip(x, y)))

cb = () -> println("accuracy = ", accuracy(data, targets))
ps = Flux.params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data, y)
Flux.Optimise.train!(loss, ps, repeatedly(minibatch, iterations), ADAM(), cb = Flux.throttle(cb, 2))


###############################################################
#  Classify test data
###############################################################
test_samples = map(readlines("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/dataset/test.json")) do s
	extractor(JSON.parse(s))
end
o = Flux.onecold(model(reduce(catobs, test_samples)).data);
ns = extract_target[:device_class].keyvalemap
ns = Dict([ v => k for (k,v) in ns]...)
o = [ns[i] for i in o]
# Id,Predicted
# crossentropy = 0.028738448 accuracy = 0.999067454149829. = F-score 0.86994
# writedlm("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/dataset/kaggle.csv",hcat(id, o), ",")
