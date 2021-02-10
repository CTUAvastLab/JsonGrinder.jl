using Flux, MLDataPattern, Mill, JsonGrinder, JSON, StatsBase, HierarchicalUtils, BenchmarkTools

load_documents_1k() = [open(JSON.parse, x) for x in readdir(joinpath(@__DIR__, "..", "examples2", "documents"), join=true)]
load_recipes() = open(joinpath(@__DIR__, "..", "examples", "recipes.json"),"r") do fid
	Vector{Dict}(JSON.parse(read(fid, String)))
end
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
	@btime reduce(catobs, mbx_vec)
	loss(mbx, mby)
	@info "$name - testing gradient"
	gs = gradient(() -> loss(mbx, mby), ps)
	@info "$name - gradient"
	@btime gradient(() -> loss(mbx, mby), ps)
	Flux.Optimise.update!(opt, ps, gs)
end
