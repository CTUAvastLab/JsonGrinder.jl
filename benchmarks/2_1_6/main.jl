using Flux, MLDataPattern, Mill, JsonGrinder, JSON, StatsBase, HierarchicalUtils, BenchmarkTools, JLD2, Random
using Pkg
include(joinpath(@__DIR__, "..", "utils.jl"))
pkg"precompile"

make_model(sch, extractor, n_classes) = reflectinmodel(sch, extractor,
	k -> Dense(k,20,relu),
	d -> meanmax_aggregation(d),
	fsm = Dict("" => k -> Dense(k, n_classes)),
)

batch_size = 500
###############################################################
# documents
###############################################################
# this loads files in examples/documents and parses them
# downloaded from https://www.kaggle.com/allen-institute-for-ai/CORD-19-research-challenge
# document_parses/pdf_json
samples, sch, extractor, targets, labelnames, data = load_prepare_documents_stuff()
model = make_model(sch, extractor, 2)
benchmark_stuff("documents", data, targets, labelnames, batch_size, model)
###############################################################
# deviceid
###############################################################
samples, sch, extractor, targets, labelnames, data = load_prepare_deviceid_stuff()
model = make_model(sch, extractor, length(labelnames))
benchmark_stuff("deviceid", data, targets, labelnames, batch_size, model)
###############################################################
# recipes
###############################################################
samples, sch, extractor, targets, labelnames, data = load_prepare_recipes_stuff()
model = make_model(sch, extractor, length(labelnames))
benchmark_stuff("recipes", data, targets, labelnames, batch_size, model)
