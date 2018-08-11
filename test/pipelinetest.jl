using Revise
using Mill, JSON, Lazy, FluxExtensions, Flux

using JsonGrinder: DictEntry, suggestextractor, schema, string2ngrams
using Mill: reflectinmodel

@testset "testing pipeline mixing different types of arrays" begin
	j1 = JSON.parse("""{"a": 1, "b": "hello works", "c":{ "a":1 ,"b": "hello world"}}""")
	j2 = JSON.parse("""{"a": 2, "b": "hello world", "c":{ "a":2 ,"b": "hello"}}""")

	schema = JsonGrinder.schema([j1,j2])
	reflector = suggestextractor(Float32,schema,0)
	dss = @>> [j1,j2] map(s-> reflector(s))
	ds = cat(dss...);
	ds = Mill.mapdata(x -> string2ngrams(x,3,101),ds)
	dss = map(s -> Mill.mapdata(x -> string2ngrams(x,3,101),s),dss)

	m,k = reflectinmodel(ds, k -> Chain(ResDense(k,10)));
	push!(m, Flux.Dense(k,2));
	o = Flux.data(m(ds).data)
	for i in 1:length(dss)
		@test all(abs.(o[:,i] .- Flux.data(m(dss[i]).data)) .< 1e-10 )
	end
end


@testset "testing pipeline with simple arrays and missing values" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	schema = JsonGrinder.schema([j1,j2,j3])
	reflector = suggestextractor(Float32,schema,0)
	dss = @>> [j1,j2,j3,j4,j5,j6] map(s-> reflector(s))
	ds = cat(dss...);
	m,k = reflectinmodel(ds, k -> Chain(ResDense(k,10)));
	push!(m, Flux.Dense(k,2));
	o = Flux.data(m(ds).data)

	for i in 1:length(dss)
		@test all(abs.(o[:,i] .- Flux.data(m(dss[i]).data)).< 1e-10)
	end
end


@testset "testing pipeline with arrays of dicts and missing values" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")

	schema = JsonGrinder.schema([j1,j2,j3])
	reflector = suggestextractor(Float32,schema,0)
	dss = @>> [j1,j2,j3,j4,j5] map(s-> reflector(s))
	ds = cat(dss...);
	m,k = reflectinmodel(ds, k -> Chain(ResDense(k,10)));
	push!(m, Flux.Dense(k,2));
	o = Flux.data(m(ds).data)
	for i in 1:length(dss)
		@test all(abs.(o[:,i] .- Flux.data(m(dss[i]).data)).< 1e-10)
	end
end
