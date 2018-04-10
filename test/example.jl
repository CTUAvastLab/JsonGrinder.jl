using Base.Test
using Flux
using MLDataPattern
using Lazy
using Revise
using Mill
using JsonGrinder
using FluxExtensions

import JsonGrinder: suggestextractor, ExtractCategorical, ExtractBranch
import Mill: mapdata, sparsify, reflectinmodel

#load all samples
samples = open("prescription.jsonl") do fid
	readlines(fid)
end

#print example of the JSON
	JSON.print(JSON.parse(samples[1]),2)

#create schema of the json
	schema = JsonGrinder.schema(samples);

# Create the extractor and modify the extractor, We discard NPI, since it is rubbish, change variables to
# one hot encoding and remove gender, as this would be the variable to predict
	reflector = suggestextractor(Float32,schema,2000);
	extract_data = ExtractBranch(nothing,reflector.other);
	extract_target = ExtractBranch(nothing,deepcopy(reflector.other));

	fnames = ["specialty","years_practicing","settlement_type","region"]
	vec = Dict(map(k -> (k,ExtractCategorical(schema["provider_variables"][k])),fnames))
	extract_data.other["provider_variables"] = ExtractBranch(vec,nothing)

	fnames = ["gender"]
	vec = Dict(map(k -> (k,ExtractCategorical(schema["provider_variables"][k])),fnames))
	extract_target.other["provider_variables"] = ExtractBranch(vec,nothing)
	delete!(extract_target.other,"cms_prescription_counts")

#once extractors are done, extract some training and testing data
	data = @>> samples[1:100000] map(s-> extract_data(JSON.parse(s)));
	data = cat(data...);
	target = @>> samples[1:100000] map(s-> extract_target(JSON.parse(s)));
	target = cat(target...);
	target = target.data.data

#make data sparse
# data = mapdata(i -> sparsify(Float32.(i),0.05),data)
data = mapdata(i -> Float32.(i),data)

# reflect the data structure in the model
	layerbuilder =  k -> ( FluxExtensions.ResDense(k,10,relu),10)
	m,k = reflectinmodel(data, layerbuilder)
	m = Mill.addlayer(m,Dense(k,2))
	m(data)

#let's do the learning
	opt = Flux.Optimise.ADAM(params(m))
	loss = (x,y) -> FluxExtensions.logitcrossentropy(m(getobs(x)),getobs(y)) 
	FluxExtensions.learn(loss,opt,RandomBatches((data,target),100,10000))

#evaluate
	accuracy = mean(Flux.argmax(m(data)) .== Flux.argmax(target))
