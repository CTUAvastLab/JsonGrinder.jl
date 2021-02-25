using Flux, MLDataPattern, Mill, JsonGrinder, JSON, StatsBase, HierarchicalUtils, BenchmarkTools

load_documents_1k() = [open(JSON.parse, x) for x in readdir(joinpath(@__DIR__, "..", "examples2", "documents"), join=true)]
load_recipes() = open(joinpath(@__DIR__, "..", "data", "recipes.json"),"r") do fid
	Vector{Dict}(JSON.parse(read(fid, String)))
end
load_recipes(n::Int) = collect(Iterators.take(load_recipes(), n))
load_deviceid() = map(JSON.parse, readlines(joinpath(@__DIR__, "..", "data", "dataset", "train.json")))

function author_cite_themself(s)
	a = [get(i["first"], 1, "") * "_" * i["last"] for i in s["metadata"]["authors"]]
	b = [get(i["first"], 1, "") * "_" * i["last"] for (k, j) in s["bib_entries"] for i in j["authors"]]
	length(intersect(a, b)) > 0
end

minibatch(data, targets, labelnames, batch_size=200, idx=sample(1:length(data), batch_size, replace = false)) =
	reduce(catobs, data[idx]), Flux.onehotbatch(targets[idx], labelnames)
minibatch_vec(data, targets, labelnames, batch_size=200, idx=sample(1:length(data), batch_size, replace = false)) =
	data[idx], Flux.onehotbatch(targets[idx], labelnames)
loss(x,y) = Flux.logitcrossentropy(model(x).data, y)

function benchmark_stuff(name, data, targets, labenames, batch_size, model)
	opt = ADAM()
	ps = Flux.params(model)
	Random.seed!(42)
	@info "$name - testing the gradient and catobsing"
	mbx, mby = minibatch(data, targets, labelnames, batch_size, collect(1:batch_size))
	Random.seed!(42)
	@info "$name - minibatch"
	@btime minibatch(data, targets, labelnames, batch_size, collect(1:batch_size))
	Random.seed!(42)
	mbx_vec, mby = minibatch_vec(data, targets, labelnames, batch_size, collect(1:batch_size))
	mbx = reduce(catobs, mbx_vec)
	@info "$name - catobs"
	@btime reduce(catobs, $mbx_vec)
	loss(mbx, mby)
	@info "$name - testing gradient"
	gs = gradient(() -> loss(mbx, mby), ps)
	@info "$name - gradient"
	@btime gradient(() -> loss($mbx, $mby), $ps)
	Flux.Optimise.update!(opt, ps, gs)
end

function load_prepare_documents_stuff()
	samples = load_documents_1k()
	sch = JsonGrinder.schema(samples)
	delete!(sch.childs,:paper_id)
	# extractor = suggestextractor(sch, (; key_as_field=13))	# for small dataset
	extractor = suggestextractor(sch, (; key_as_field=300))
	targets = author_cite_themself.(samples)
	labelnames = unique(targets)
	data = extractor.(samples)
	samples, sch, extractor, targets, labelnames, data
end

function load_prepare_deviceid_stuff()
	samples = load_deviceid()
	labelkey = "device_class"
	targets = map(i -> i[labelkey], samples)
	foreach(i -> delete!(i, labelkey), samples)
	foreach(i -> delete!(i, "device_id"), samples)
	sch = JsonGrinder.schema(samples)
	extractor = suggestextractor(sch)
	labelnames = unique(targets)
	data = extractor.(samples)
	samples, sch, extractor, targets, labelnames, data
end

function load_prepare_recipes_stuff()
	samples = load_recipes(500)
	sch = JsonGrinder.schema(samples)
	targets = map(i -> i["cuisine"], samples)
	delete!(sch.childs,:id)
	delete!(sch.childs,:cuisine)
	extractor = suggestextractor(sch)
	labelnames = unique(targets)
	data = extractor.(samples)
	samples, sch, extractor, targets, labelnames, data
end
