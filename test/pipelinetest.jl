using Mill, JSON, Flux, JsonGrinder, Test

using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

@testset "testing pipeline mixing different types of arrays" begin
	j1 = JSON.parse("""{"a": 1, "b": "hello works", "c":{ "a":1 ,"b": "hello world"}}""")
	j2 = JSON.parse("""{"a": 2, "b": "hello world", "c":{ "a":2 ,"b": "hello"}}""")

	sch = schema([j1,j2])
	extractor = suggestextractor(sch)
	ds = map(s-> extractor(s), [j1,j2])
	dss = reduce(catobs, ds)

	m = reflectinmodel(dss, k -> Dense(k,10, relu));
	o = m(dss).data
	for i in 1:length(ds)
		@test o[:,i] ≈ m(ds[i]).data
	end
end


@testset "testing pipeline with simple arrays and missing values" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3])
	extractor = suggestextractor(sch)
	dss = map(extractor, [j1,j2,j3,j4,j5,j6])
	ds = reduce(catobs, dss)
	m = reflectinmodel(ds, k -> Dense(k,10, relu));
	o = m(ds).data

	for i in 1:length(dss)
		@test o[:,i] ≈ m(dss[i]).data
	end
end


@testset "testing pipeline with arrays of dicts and missing values" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3])
	with_merge_scalars(false) do
		extractor = suggestextractor(sch)
		dss = map(s-> extractor(s), [j1,j2,j3,j4,j5])
		ds = reduce(catobs, dss)
		m = reflectinmodel(ds, k -> Dense(k,10, relu))
		@test ds.data isa ProductNode
		@test ds.data[:a] isa ArrayNode
		@test ds.data[:b] isa ArrayNode
		@test buf_printtree(ds) == 
		"""
		BagNode with 5 bag(s)
		  └── ProductNode
		        ├── a: ArrayNode(1, 5)
		        └── b: ArrayNode(1, 5)"""
		o = m(ds).data
		for i in 1:length(dss)
			@test o[:,i] ≈ m(dss[i]).data
		end
	end
	
	with_merge_scalars(true) do
		extractor = suggestextractor(sch)
		dss = map(s-> extractor(s), [j1,j2,j3,j4,j5])
		ds = reduce(catobs, dss)
		m = reflectinmodel(ds, k -> Dense(k,10, relu))
		@test ds.data isa ArrayNode
		@test buf_printtree(ds) == 
		"""
		BagNode with 5 bag(s)
		  └── ArrayNode(2, 5)"""
		o = m(ds).data
		for i in 1:length(dss)
			@test o[:,i] ≈ m(dss[i]).data
		end
	end
end
