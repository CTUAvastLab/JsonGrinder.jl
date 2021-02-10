using Flux, MLDataPattern, Mill, JsonGrinder, JSON, StatsBase, HierarchicalUtils, BenchmarkTools, JLD2, Random
using Pkg
pkg"precompile"

make_model(sch, extractor, n_classes) = reflectinmodel(sch, extractor,
	k -> Dense(k,20,relu),
	d -> SegmentedMeanMax(d),
	fsm = Dict("" => k -> Dense(k, n_classes)),
)

###############################################################
# documents
###############################################################
# this loads files in examples/documents and parses them
# downloaded from https://www.kaggle.com/allen-institute-for-ai/CORD-19-research-challenge
# document_parses/pdf_json

# samples = [open(JSON.parse, x) for x in readdir("examples/documents", join=true)]
# samples = [open(JSON.parse, x) for x in readdir("examples2/documents_100", join=true)]
samples = collect(Iterators.take(load_documents_1k(), 500))
# samples = samples[1:800]
sch = JsonGrinder.schema(samples)
delete!(sch.childs,:paper_id)
# extractor = suggestextractor(sch, (; key_as_field=13))	# for small dataset
extractor = suggestextractor(sch, (; key_as_field=300))
targets = author_cite_themself.(samples)
labelnames = unique(targets)
extractor(JsonGrinder.sample_synthetic(sch, empty_dict_vals=true))
data = extractor.(samples)
batch_size = 300
model = make_model(sch, extractor, 2)
benchmark_stuff("documents", data, targets, labelnames, batch_size, model)
###############################################################
# deviceid
###############################################################
samples = collect(Iterators.take(load_deviceid(), 500))
labelkey = "device_class"
targets = map(i -> i[labelkey], samples)
foreach(i -> delete!(i, labelkey), samples)
foreach(i -> delete!(i, "device_id"), samples)
sch = JsonGrinder.schema(samples)
extractor = suggestextractor(sch)
data = extractor.(samples)
labelnames = unique(targets)
model = make_model(sch, extractor, length(labelnames))
benchmark_stuff("deviceid", data, targets, labelnames, batch_size, model)
###############################################################
# recipes
###############################################################
samples = collect(Iterators.take(load_recipes(), 500))
sch = JsonGrinder.schema(samples)
delete!(sch.childs,:id)
extractor = suggestextractor(sch)
extract_data = ExtractDict(nothing, deepcopy(extractor.other))
extract_target = ExtractDict(nothing, deepcopy(extractor.other))
delete!(extract_target.other, :ingredients)
delete!(extract_data.other, :cuisine)
labelnames = unique(keys(sch[:cuisine]))
extract_target.other[:cuisine] = JsonGrinder.ExtractCategorical(labelnames)
data = extract_data.(samples)
target = mapreduce(extract_target, catobs, samples).data
model = make_model(sch, extract_data, size(target, 1))
benchmark_stuff("recipes", data, targets, labelnames, batch_size, model)
