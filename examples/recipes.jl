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
samples = open("recipes.json","r") do fid 
	Array{Dict}(JSON.parse(readstring(fid)))
end
schema = JsonGrinder.schema(Array{Dict}(samples));
delete!(schema.childs,"id")

# Create the extractor and modify the extractor, We discard NPI, since it is rubbish, change variables to
# one hot encoding and remove gender, as this would be the variable to predict
reflector = suggestextractor(Float32,schema,2000);
extract_data = ExtractBranch(nothing,reflector.other);
extract_target = ExtractBranch(nothing,deepcopy(reflector.other));
delete!(extract_target.other,"ingredients")
delete!(extract_data.other,"cuisine")
extract_target.other["cuisine"] = JsonGrinder.ExtractCategorical(keys(schema.childs["cuisine"]))

#once extractors are done, extract some training and testing data
data = @>> samples map(extract_data);
data = cat(data...);
target = @>> samples map(extract_target);
target = cat(target...);
target = target.data

function sentence2ngrams(ss::Array{T,N}) where {T<:AbstractString,N}
	function f(s)
		x = JsonGrinder.string2ngrams(split(s),3,2057)
		Mill.DataNode(x,[1:size(x,2)],nothing)
	end
	cat(map(f,ss)...)
end
sentence2ngrams(x) = x

data = mapdata(sentence2ngrams,data)
data = mapdata(i -> sparsify(Float32.(i),0.05),data)

# reflect the data structure in the model
layerbuilder =  k -> FluxExtensions.ResDense(k,20,relu)
m,k = reflectinmodel(data, layerbuilder)
m = Mill.addlayer(m,Dense(k,size(target,1)))
m = Adapt.adapt(Float32,m)
m(data)

#let's do the learning
opt = Flux.Optimise.ADAM(params(m))
loss = (x,y) -> FluxExtensions.logitcrossentropy(m(getobs(x)),getobs(y)) 
FluxExtensions.learn(loss,opt,RandomBatches((data,target),100,10000))

#calculate the accuracy
accuracy = mean(Flux.argmax(m(data)) .== Flux.argmax(target))


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
