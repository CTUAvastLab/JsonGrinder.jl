using Flux, MLDataPattern, Mill, JsonGrinder, JSON, StatsBase, HierarchicalUtils, BenchmarkTools

###############################################################
# start by loading all samples
###############################################################
# this loads files in examples/documents and parses them
# downloaded from https://www.kaggle.com/allen-institute-for-ai/CORD-19-research-challenge
# document_parses/pdf_json

samples = [open(JSON.parse, x) for x in readdir("examples2/documents", join=true)]
sch = JsonGrinder.schema(samples)

generate_html("documents_schema.html", sch)
delete!(sch.childs,:paper_id)
extractor = suggestextractor(sch, (; key_as_field=300))

s = samples[1]

function author_cite_themself(s)
	a = [get(i["first"], 1, "") * "_" * i["last"] for i in s["metadata"]["authors"]]
	b = [get(i["first"], 1, "") * "_" * i["last"] for (k, j) in s["bib_entries"] for i in j["authors"]]
	length(intersect(a, b)) > 0
end

targets = author_cite_themself.(samples)
countmap(targets)
labelnames = unique(targets)

TypeIterator(MultipleRepresentation, extractor) |> collect
JsonGrinder.sample_synthetic(sch, empty_dict_vals=true)

model = reflectinmodel(sch, extractor,
	k -> Dense(k,20,relu),
	d -> SegmentedMeanMax(d),
	fsm = Dict("" => k -> Dense(k, 2)),
)

opt = Flux.Optimise.ADAM()
loss(x,y) = Flux.logitcrossentropy(model(x).data, y)

data = extractor.(samples)
batch_size = 20

function minibatch()
	idx = sample(1:length(data), batch_size, replace = false)
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
end


cb = () -> println("accuracy = ",mean(Flux.onecold(m(valdata[1]).data) .== Flux.onecold(valdata[2])))
#iterations = 1000
iterations = 100
ps = Flux.params(model)

@info "testing the gradient and catobsing"
mbx, mby = minibatch()
@btime minibatch()
loss(mbx, mby)

gs = gradient(() -> loss(mbx, mby), ps)
@btime gradient(() -> loss(mb...), ps)
Flux.Optimise.update!(opt, ps, gs)


###############################################################
# we convert JSONs to Datasets
###############################################################
# advised to use all the samples, this is just speedup to demonstrate functionality
data = tmap(extract_data, samples[1:5_000])
data = reduce(catobs, data)
target = tmap(extract_target, samples[1:5_000])
target = reduce(catobs, target)[:cuisine].data
