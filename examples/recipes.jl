using Flux, MLDataPattern, Mill, JsonGrinder, JSON, Statistics, BenchmarkTools, ThreadTools
import JsonGrinder: suggestextractor, ExtractCategorical, ExtractBranch
import Mill: mapdata, sparsify, reflectinmodel

###############################################################
# start by loading all samples
###############################################################
samples = open("examples/recipes.json","r") do fid
	Vector{Dict}(JSON.parse(read(fid, String)))
end
JSON.print(samples[1],2)


###############################################################
# create schema of the JSON
###############################################################
sch = JsonGrinder.schema(samples)

###############################################################
# create extractor and split it into one for loading targets and
# one for loading data, using custom function to set conditions for using n-gram representation
###############################################################
delete!(sch.childs,"id")

limituse(d::Dict{T,Int}, limit) where {T<:AbstractString} = String.(limituse(d, limit))
limituse(d::Dict{T,Int}, limit) where {T} = collect(filter(k -> d[k] >= limit, keys(d)))

function custom_scalar_extractor()
	[(e -> promote_type(unique(typeof.(keys(e.counts)))...) <: String,
		e -> MultipleRepresentation((ExtractCategorical(limituse(e.counts, 10)), JsonGrinder.ExtractString(String)))),
	 (e -> (length(keys(e.counts)) / e.updated < 0.1  && length(keys(e.counts)) <= 10000),
		e -> ExtractCategorical(collect(keys(e.counts)))),
	 (e -> true,
		e -> extractscalar(promote_type(unique(typeof.(keys(e.counts)))...))),]
end

extractor = suggestextractor(sch, (scalar_extractors=custom_scalar_extractor(), mincount=100,))

extract_data = ExtractBranch(nothing,deepcopy(extractor.other))
extract_target = ExtractBranch(nothing,deepcopy(extractor.other))
delete!(extract_target.other,"ingredients")
delete!(extract_data.other,"cuisine")
extract_target.other["cuisine"] = JsonGrinder.ExtractCategorical(keys(sch.childs["cuisine"]))

extract_data(JsonGrinder.sample_synthetic(sch))
###############################################################
# we convert JSONs to Datasets
###############################################################
data = tmap(extract_data, samples)
data = reduce(catobs, data)
target = tmap(extract_target, samples)
target = reduce(catobs, target).data

e = sch["cuisine"]

###############################################################
# 	create the model according to the data
###############################################################
m = reflectinmodel(data[1:10],
	k -> Dense(k,20,relu),
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, size(target, 1)))
)

m2 = reflectinmodel(extract_data(JsonGrinder.sample_synthetic(sch)),
	k -> Dense(k,20,relu),
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, size(target, 1)))
)

m2 = reflectinmodel(sch,
	k -> Dense(k,20,relu),
	d -> SegmentedMeanMax(d),
	b = Dict("" => k -> Dense(k, size(target, 1)))
)

###############################################################
#  train
###############################################################
opt = Flux.Optimise.ADAM()
loss = (x,y) -> Flux.logitcrossentropy(m(getobs(x)).data,getobs(y))
valdata = data[1:1000],target[:,1:1000]
data, target = data[1001:nobs(data)], target[:,1001:size(target,2)]
cb = () -> println("accuracy = ",mean(Flux.onecold(Flux.data(m(valdata[1]).data)) .== Flux.onecold(valdata[2])))
#todo: fix this
Flux.Optimise.train!(loss, RandomBatches((data,target),100,10000), opt, cb = Flux.throttle(cb, 10))

#calculate the accuracy
mean(Flux.onecold(m(data).data) .== Flux.onecold(target))

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

# schema can also be created in parallel for better performance, compare:

# single threaded
@btime JsonGrinder.schema(samples)
# multi threaded
@btime merge(tmap(x->JsonGrinder.schema(collect(x)), Iterators.partition(samples, 10_000))...)
