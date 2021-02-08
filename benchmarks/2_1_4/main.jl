using Flux, MLDataPattern, Mill, JsonGrinder, JSON, StatsBase, HierarchicalUtils, BenchmarkTools, JLD2, Random
using Pkg
pkg"precompile"
###############################################################
# start by loading all samples
###############################################################
# this loads files in examples/documents and parses them
# downloaded from https://www.kaggle.com/allen-institute-for-ai/CORD-19-research-challenge
# document_parses/pdf_json

# samples = [open(JSON.parse, x) for x in readdir("examples/documents", join=true)]
# samples = [open(JSON.parse, x) for x in readdir("examples2/documents_100", join=true)]
samples = [open(JSON.parse, x) for x in readdir(joinpath(@__DIR__, "..", "..", "examples2", "documents"), join=true)]
# samples = samples[1:800]
sch = JsonGrinder.schema(samples)

# generate_html("documents_schema.html", sch)
delete!(sch.childs,:paper_id)
# extractor = suggestextractor(sch, (; key_as_field=13))	# for small dataset
extractor = suggestextractor(sch, (; key_as_field=300))
# JLD2.@load "model_etc.jld2" model sch extractor
# JLD2.@load "mb.jld2" mbx mby
s = samples[1]

function author_cite_themself(s)
	a = [get(i["first"], 1, "") * "_" * i["last"] for i in s["metadata"]["authors"]]
	b = [get(i["first"], 1, "") * "_" * i["last"] for (k, j) in s["bib_entries"] for i in j["authors"]]
	length(intersect(a, b)) > 0
end
author_cite_themself(s)

targets = author_cite_themself.(samples)
countmap(targets)
labelnames = unique(targets)

extractor(JsonGrinder.sample_synthetic(sch, empty_dict_vals=true))

model = reflectinmodel(sch, extractor,
	k -> Dense(k,20,relu),
	d -> SegmentedMeanMax(d),
	fsm = Dict("" => k -> Dense(k, 2)),
)

opt = Flux.Optimise.ADAM()
loss(x,y) = Flux.logitcrossentropy(model(x).data, y)

data = extractor.(samples)
batch_size = 200
# batch_size = 20
# batch_size = 10

function minibatch()
	idx = sample(1:length(data), batch_size, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end

function minibatch_vec()
	idx = sample(1:length(data), batch_size, replace = false)
	data[idx], Flux.onehotbatch(targets[idx], labelnames)
end


cb = () -> println("accuracy = ",mean(Flux.onecold(m(valdata[1]).data) .== Flux.onecold(valdata[2])))
#iterations = 1000
iterations = 100
ps = Flux.params(model)
# JLD2.@save "model_etc.jld2" model sch extractor
Random.seed!(42)
@info "testing the gradient and catobsing"
mbx, mby = minibatch()
# JLD2.@save "mb.jld2" mbx mby
Random.seed!(42)
@info "minibatch"
@btime minibatch()
Random.seed!(42)
mbx_vec, mby = minibatch_vec()
mbx = reduce(catobs, mbx_vec)
@info "catobs"
@btime reduce(catobs, mbx_vec)
# 5.835 ms (24124 allocations: 1.51 MiB)
# 10.912 ms (22649 allocations: 1.43 MiB)
loss(mbx, mby)
@info "testing gradient"
gs = gradient(() -> loss(mbx, mby), ps)
@info "gradient"
@btime gradient(() -> loss(mbx, mby), ps)
# 67.214 ms (58575 allocations: 29.60 MiB)
# 93.755 ms (59645 allocations: 42.19 MiB)
Flux.Optimise.update!(opt, ps, gs)


###############################################################
# we convert JSONs to Datasets
###############################################################
# advised to use all the samples, this is just speedup to demonstrate functionality
data = tmap(extract_data, samples[1:5_000])
data = reduce(catobs, data)
target = tmap(extract_target, samples[1:5_000])
target = reduce(catobs, target)[:cuisine].data
