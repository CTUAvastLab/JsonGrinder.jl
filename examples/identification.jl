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


###############################################################
# create schema of the JSON
###############################################################
sch = JsonGrinder.schema(samples);
extractor = suggestextractor(sch)
extract_target = ExtractDict(nothing, Dict("device_class" => extractor.other["device_class"]));

target = extractbatch(extract_target, samples).data
delete!(extractor.other, "device_class");
data = extractbatch(extractor, samples)

ds = extractor(JsonGrinder.sample_synthetic(sch))
model = reflectinmodel(ds, d -> Dense(d,20, relu), d -> SegmentedMeanMax(d), b = Dict("" => d -> Chain(Dense(d, 20, relu), Dense(20, size(target,1)))));
model(ds)

###############################################################
#  train
###############################################################
function makebatch()
	i = rand(1:nobs(data), 100)
	data[i], target[:,i]
end
opt = ADAM()
ps = params(model)
loss = (x,y) -> Flux.logitcrossentropy(model(x).data,y)

cb = () -> begin
	o = model(data).data
	println("crossentropy = ",Flux.logitcrossentropy(o,target) ," accuracy = ",mean(Flux.onecold(softmax(o)) .== Flux.onecold(target)))
end
Flux.Optimise.train!(loss, ps, repeatedly(makebatch,10000), opt, cb = Flux.throttle(cb, 60))

# serialize("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/device_model.jls",(model, extractor, schema))
###############################################################
#  Let's demonstrate the explainability
###############################################################
(model, extractor, schema) = deserialize("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/device_model.jls")
using ExplainMill
i = 3
j = argmax(model(data[i]).data)[1]
argmax(target[i]) == j
eds = explain(data[i], model, j)
print_explained(eds, extractor)

###############################################################
#  Classify test data
###############################################################
test_samples = map(readlines("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/dataset/test.json")) do s
	extract_data(JSON.parse(s))
end
o = Flux.onecold(model(reduce(catobs, test_samples)).data);
ns = extract_target.vec["device_class"].items
o = [ns[i] for i in o];
id = [s["device_id"] for s in test_samples];

# Id,Predicted
# crossentropy = 0.028738448 accuracy = 0.999067454149829. = F-score 0.86994
writedlm("/Users/tomas.pevny/Work/Presentations/JuliaMeetup/dataset/kaggle.csv",hcat(id, o), ",")
