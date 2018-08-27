using Flux, MLDataPattern, Mill, JsonGrinder, FluxExtensions, JSON, Statistics, Adapt

import JsonGrinder: suggestextractor, ExtractCategorical, ExtractBranch
import Mill: mapdata, sparsify, reflectinmodel

###############################################################
# start by loading all samples
###############################################################
samples = open("recipes.json","r") do fid 
	Array{Dict}(JSON.parse(readstring(fid)))
end
JSON.print(samples[1],2)


###############################################################
# create schema of the JSON
###############################################################
schema = JsonGrinder.schema(samples);

###############################################################
# create extractor and split it into one for loading targets and
# one for loading data
###############################################################
delete!(schema.childs,"id");
extractor = suggestextractor(Float32,schema,2000);
extract_data = ExtractBranch(nothing,deepcopy(extractor.other));
extract_target = ExtractBranch(nothing,deepcopy(extractor.other));
delete!(extract_target.other,"ingredients");
delete!(extract_data.other,"cuisine");
extract_target.other["cuisine"] = JsonGrinder.ExtractCategorical(keys(schema.childs["cuisine"]));


###############################################################
# we convert JSONs to Datasets
###############################################################
data = map(extract_data, samples);
data = cat(data...);
target = map(extract_target, samples);
target = cat(target...).data;

###############################################################
# convert Strings to n-grams
###############################################################
function sentence2ngrams(ss::Array{T,N}) where {T<:AbstractString,N}
	function f(s)
		x = JsonGrinder.string2ngrams(split(s),3,2057)
		Mill.BagNode(Mill.ArrayNode(x),[1:size(x,2)])
	end
	cat(map(f,ss)...)
end
sentence2ngrams(x) = x

data = mapdata(sentence2ngrams,data)
data = mapdata(i -> sparsify(Float32.(i),0.05),data)

###############################################################
# 	create the model according to the data
###############################################################
m,k = reflectinmodel(data[1:10], k -> Chain(FluxExtensions.ResDense(k,20,relu)))
push!(m,Dense(k,size(target,1)))
m = Adapt.adapt(Float32,m)
m(data)

###############################################################
#  train
###############################################################
opt = Flux.Optimise.ADAM(params(m))
loss = (x,y) -> Flux.logitcrossentropy(m(getobs(x)).data,getobs(y)) 
valdata = data[1:1000],target[:,1:1000]
data, target = data[1001:nobs(data)], target[:,1001:size(target,2)]
cb = () -> println("accuracy = ",mean(Flux.onecold(Flux.data(m(valdata[1]).data)) .== Flux.onecold(valdata[2])))
Flux.Optimise.train!(loss, RandomBatches((data,target),100,10000), opt, cb = Flux.throttle(cb, 10))

#calculate the accuracy
mean(Flux.onecold(Flux.data(m(data).data)) .== Flux.onecold(target))

# samples = open("recipes_test.json","r") do fid 
# 	Array{Dict}(JSON.parse(readstring(fid)))
# end
# ids = map(s -> s["id"],samples)
# tstdata = @>> samples map(extract_data);
# tstdata = cat(tstdata...);
# tstdata = mapdata(sentence2ngrams,tstdata)
# tstdata = mapdata(i -> sparsify(Float32.(i),0.05),tstdata)
# names = extract_target.other["cuisine"].items
# y = map(i -> names[i],Flux.argmax(m(tstdata)));


# using DataFrames
# CSV.write("cuisine.csv",DataFrame(id = ids,cuisine = y ),delim=',')
