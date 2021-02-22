using Mill, JSON, Flux, JsonGrinder, Test, HierarchicalUtils, Setfield

using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

@testset "testing pipeline mixing different types of arrays" begin
	j1 = JSON.parse("""{"a": 1, "b": "hello works", "c":{ "a":1 ,"b": "hello world"}}""")
	j2 = JSON.parse("""{"a": 2, "b": "hello world", "c":{ "a":2 ,"b": "hello"}}""")

	sch = schema([j1,j2])
	extractor = suggestextractor(sch)
	ds = extractor.([j1,j2])
	dss = reduce(catobs, ds)

	m = reflectinmodel(dss, k -> Dense(k,10, relu))
	o = m(dss).data
	for i in 1:length(ds)
		@test o[:,i] ≈ m(ds[i]).data
	end
end


@testset "testing pipeline with simple arrays and missing values" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": {"a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3], "b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	extractor = suggestextractor(sch)
	dss = extractor.([j1,j2,j3,j4,j5,j6])
	ds = reduce(catobs, dss)
	m = reflectinmodel(ds, k -> Dense(k,10, relu))
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
	extractor = suggestextractor(sch)
	dss = extractor.([j1,j2,j3,j4,j5])
	ds = extractbatch(extractor, [j1,j2,j3,j4,j5])
	@test isequal(reduce(catobs, dss), ds)
	m = reflectinmodel(ds, k -> Dense(k,10, relu))
	o = m(ds).data
	for i in 1:length(dss)
		@test o[:,i] ≈ m(dss[i]).data
	end
	@test m.m.m == identity
	@test size(dss[4][:a].data[:a].data) == (3, 0)
end

@testset "testing pipeline with single-keyed dicts and merging scalars" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2,"c":"oh"}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3,"c":"hi"},{"b":2,"a":1,"c":"Mark"}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4, j5])
	ext = suggestextractor(sch)
	dss = ext.([j1,j2,j3,j4,j5])
	ds = reduce(catobs, dss)
	m = reflectinmodel(ds, k -> Dense(k, 10, relu))

	@test isequal(NodeIterator(m, ds) |> collect, [
		(m[""], ds[""]),
		(m["U"], ds["U"]),
		(m["k"], ds["k"]),
		(m["o"], ds["o"]),
		(m["s"], ds["s"]),
		(m["w"], ds["w"]),
	])
	@test NodeIterator(sch, ext) |> collect == [
		(sch[""], ext[""]),
		(sch["U"], ext["U"]),
		(sch["k"], ext["k"]),
		(sch["o"], ext["o"]),
		(sch["s"], ext["s"]),
		(sch["w"], ext["w"]),
	]
	@test NodeIterator(sch, m) |> collect == [
		(sch[""], m[""]),
		(sch["U"], m["U"]),
		(sch["k"], m["k"]),
		(sch["o"], m["o"]),
		(sch["s"], m["s"]),
		(sch["w"], m["w"]),
	]
	@test NodeIterator(ext, m) |> collect == [
		(ext[""], m[""]),
		(ext["U"], m["U"]),
		(ext["k"], m["k"]),
		(ext["o"], m["o"]),
		(ext["s"], m["s"]),
		(ext["w"], m["w"]),
	]
	@test isequal(NodeIterator(ext, ds) |> collect, [
		(ext[""], ds[""]),
		(ext["U"], ds["U"]),
		(ext["k"], ds["k"]),
		(ext["o"], ds["o"]),
		(ext["s"], ds["s"]),
		(ext["w"], ds["w"]),
	])
	@test buf_printtree(sch) == """
	[Dict] (updated = 5)
	  └── a: [List] (updated = 4)
	           └── [Dict] (updated = 5)
	                 ├── a: [Scalar - Int64], 2 unique values, updated = 4
	                 ├── b: [Scalar - Int64], 2 unique values, updated = 4
	                 └── c: [Scalar - String], 3 unique values, updated = 3"""
	@test buf_printtree(ext) == """
	Dict
	  └── a: Array of
	           └── Dict
	                 ├── a: Categorical d = 3
	                 ├── b: Categorical d = 3
	                 └── c: String"""
	@test buf_printtree(m) == """
	ProductModel … ↦ ArrayModel(identity)
	  └── a: BagModel … ↦ ⟨SegmentedMean(10), SegmentedMax(10)⟩ ↦ ArrayModel(Dense(21, 10, relu))
	           └── ProductModel … ↦ ArrayModel(Dense(30, 10, relu))
	                 ├── a: ArrayModel([post_imputing]Dense(3, 10, relu))
	                 ├── b: ArrayModel([post_imputing]Dense(3, 10, relu))
	                 └── c: ArrayModel([post_imputing]Dense(2053, 10, relu))"""
	@test buf_printtree(ds) == """
	ProductNode with 5 obs
	  └── a: BagNode with 5 obs
	           └── ProductNode with 5 obs
	                 ├── a: ArrayNode(3×5 MaybeHotMatrix with Union{Missing, Bool} elements) with 5 obs
	                 ├── b: ArrayNode(3×5 MaybeHotMatrix with Union{Missing, Bool} elements) with 5 obs
	                 └── c: ArrayNode(2053×5 NGramMatrix with Union{Missing, Int64} elements) with 5 obs"""

	@test m[""].m.m == identity

	@test nobs(dss[5]["s"].data) == 0
	@test nobs(dss[5]) == 1
end
