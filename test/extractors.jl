using JsonGrinder, JSON, Test, SparseArrays, Flux, Random
using JsonGrinder: ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector
using Mill: catobs, nobs
using LinearAlgebra

@testset "Testing scalar conversion" begin
	sc = ExtractScalar(Float64,2,3)
	@test all(sc("5").data .== [9])
	@test all(sc(5).data .== [9])
	@test all(sc(nothing).data .== [0])
end

@testset "Testing array conversion" begin
	sc = ExtractArray(ExtractCategorical(2:4))
	@test all(sc([2,3,4]).data.data .== Matrix(1.0I, 4, 3))
	@test nobs(sc(nothing).data) == 0
	@test all(sc(nothing).bags.bags .== [0:-1])
	sc = ExtractArray(ExtractScalar(Float64))
	@test all(sc([2,3,4]).data.data .== [2 3 4])
	@test nobs(sc(nothing).data) == 0
	@test all(sc(nothing).bags.bags .== [0:-1])
end

@testset "Testing feature vector conversion" begin
	sc = ExtractVector(5)
	@test all(sc([1, 2, 2, 3, 4]).data .== [1, 2, 2, 3, 4])
	@test sc([1, 2, 2, 3, 4]).data isa Array{Float32, 2}
	sc = ExtractVector{Int64}(5)
	@test all(sc([1, 2, 2, 3, 4]).data .== [1, 2, 2, 3, 4])
	@test sc([1, 2, 2, 3, 4]).data isa Array{Int64, 2}
	@test all(sc(nothing).data .== [0, 0, 0, 0, 0])

	@test !JsonGrinder.extractsmatrix(sc)

	# feature vector longer than expected
	sc = ExtractVector(5)
	@test all(sc([1, 2, 2, 3, 4, 5]).data .== [1, 2, 2, 3, 4])
end

@testset "Testing ExtractDict" begin
	vector = Dict("a" => ExtractScalar(Float64,2,3),"b" => ExtractScalar(Float64));
	other = Dict("c" => ExtractArray(ExtractScalar(Float64,2,3)));
	br = ExtractDict(vector,other)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
	a2 = br(Dict("a" => 5, "b" => 7))
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))
	@test all(catobs(a1,a1).data[1].data .==[7 7; 9 9])
	@test all(catobs(a1,a1).data[2].data.data .== [-3 0 3 6 -3 0 3 6])
	@test all(catobs(a1,a1).data[2].bags .== [1:4,5:8])

	@test all(catobs(a1,a2).data[1].data .==[7 7; 9 9])
	@test all(catobs(a1,a2).data[2].data.data .== [-3 0 3 6])
	@test all(catobs(a1,a2).data[2].bags .== [1:4,0:-1])

	@test all(catobs(a2,a3).data[1].data .==[7 0; 9 9])
	@test all(catobs(a2,a3).data[2].data.data .== [-3 0 3 6])
	@test all(catobs(a2,a3).data[2].bags .== [0:-1,1:4])

	@test all(catobs(a1,a3).data[1].data .==[7 0; 9 9])
	@test all(catobs(a1,a3).data[2].data.data .== [-3 0 3 6 -3 0 3 6])
	@test all(catobs(a1,a3).data[2].bags .== [1:4,5:8])

	br = ExtractDict(vector,nothing)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
	a2 = br(Dict("a" => 5, "b" => 7))
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))
	@test all(a1.data .==[7; 9])
	@test all(a2.data .==[7; 9])
	@test all(a3.data .==[0; 9])

	br = ExtractDict(nothing,other)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
	a2 = br(Dict("a" => 5, "b" => 7))
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))

	@test all(a1.data.data .== [-3 0 3 6])
	@test all(a1.bags .== [1:4])
	@test all(catobs(a1,a1).data.data .== [-3 0 3 6 -3 0 3 6])
	@test all(catobs(a1,a1).bags .== [1:4,5:8])

	@test all(catobs(a1,a2).data.data .== [-3 0 3 6])
	@test all(catobs(a1,a2).bags .== [1:4,0:-1])


	@test all(a3.data.data .== [-3 0 3 6])
	@test all(a3.bags .== [1:4])
	@test all(catobs(a3,a3).data.data .== [-3 0 3 6 -3 0 3 6])
	@test all(catobs(a3,a3).bags .== [1:4,5:8])
end

@testset "Testing Nested Missing Arrays" begin
	other = Dict("a" => ExtractArray(ExtractScalar(Float64,2,3)),"b" => ExtractArray(ExtractScalar(Float64,2,3)));
	br = ExtractDict(nothing,other)
	a1 = br(Dict("a" => [1,2,3], "b" => [1,2,3,4]))
	a2 = br(Dict("b" => [2,3,4]))
	a3 = br(Dict("a" => [2,3,4]))
	a4 = br(Dict{String,Any}())

	@test all(catobs(a1,a2).data[1].data.data .== [-3.0  0.0  3.0  6.0  0.0  3.0  6.0])
	@test all(catobs(a1,a2).data[1].bags .== [1:4, 5:7])
	@test all(catobs(a1,a2).data[2].data.data .== [-3.0  0.0  3.0])
	@test all(catobs(a1,a2).data[2].bags .== [1:3, 0:-1])


	@test all(catobs(a2,a3).data[1].data.data .== [0.0  3.0  6.0])
	@test all(catobs(a2,a3).data[1].bags .== [1:3, 0:-1])
	@test all(catobs(a2,a3).data[2].data.data .== [0 3 6])
	@test all(catobs(a2,a3).data[2].bags .== [0:-1, 1:3])


	@test all(catobs(a1,a4).data[1].data.data .== [-3.0  0.0  3.0  6.0])
	@test all(catobs(a1,a4).data[1].bags .== [1:4, 0:-1])
	@test all(catobs(a1,a4).data[2].data.data .== [-3.0  0.0  3.0])
	@test all(catobs(a1,a4).data[2].bags .== [1:3, 0:-1])
end

@testset "ExtractOneHot" begin
	samples = ["{\"name\": \"a\", \"count\" : 1}",
		"{\"name\": \"b\", \"count\" : 2}",]
	vs = JSON.parse.(samples)

	e = ExtractOneHot(["a","b"], "name", "count")
	@test e(vs).data[:] ≈ [1, 2, 0]
	@test e(nothing).data[:] ≈ [0, 0, 0]
	@test typeof(e(vs).data) == SparseMatrixCSC{Float32,Int64}
	@test typeof(e(nothing).data) == SparseMatrixCSC{Float32,Int64}


	e = ExtractOneHot(["a","b"], "name", nothing)
	@test e(vs).data[:] ≈ [1, 1, 0]
	@test e(nothing).data[:] ≈ [0, 0, 0]
	@test typeof(e(vs).data) == SparseMatrixCSC{Float32,Int64}
	@test typeof(e(nothing).data) == SparseMatrixCSC{Float32,Int64}
	vs = JSON.parse.(["{\"name\": \"c\", \"count\" : 1}"])
	@test e(vs).data[:] ≈ [0, 0, 1]
	@test typeof(e(vs).data) == SparseMatrixCSC{Float32,Int64}
end

@testset "ExtractCategorical" begin
	e = ExtractCategorical(["a","b"])
	@test e("a").data[:] ≈ [1, 0, 0]
	@test e("b").data[:] ≈ [0, 1, 0]
	@test e("z").data[:] ≈ [0, 0, 1]
	@test e(nothing).data[:] ≈ [0, 0, 1]
	@test typeof(e("a").data) == Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}
	@test typeof(e(nothing).data) == Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}

	@test e(["a", "b"]).data ≈ [1 0; 0 1; 0 0]
	@test typeof(e(["a", "b"]).data) == Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}
end

@testset "equals and hash test" begin
	other1 = Dict(
		"a" => ExtractArray(ExtractScalar(Float64,2,3)),
		"b" => ExtractArray(ExtractScalar(Float64,2,3)),
		"c" => ExtractCategorical(["a","b"]),
		"d" => ExtractVector(4),
	)
	br1 = ExtractDict(nothing,other1)
	other11 = Dict(
		"a" => ExtractArray(br1),
		"b" => ExtractScalar(Float64,2,3),
	)
	br11 = ExtractDict(nothing,other11)

	other2 = Dict(
		"a" => ExtractArray(ExtractScalar(Float64,2,3)),
		"b" => ExtractArray(ExtractScalar(Float64,2,3)),
		"c" => ExtractCategorical(["a","b"]),
		"d" => ExtractVector(4),
	)
	br2 = ExtractDict(nothing,other2)
	other22 = Dict("a" => ExtractArray(br2), "b" => ExtractScalar(Float64,2,3))
	br22 = ExtractDict(nothing,other22)

	@test hash(br11) === hash(br22)
	@test hash(br11) !== hash(br1)
	@test hash(br11) !== hash(br2)
	@test hash(br1) === hash(br2)

	@test br11 == br22
	@test br11 != br1
	@test br11 != br2
	@test br1 == br2
end

@testset "Extractor of keys as field" begin
	JsonGrinder.updatemaxkeys!(1000)
	js = [Dict(randstring(5) => rand()) for _ in 1:1000];
	sch = JsonGrinder.schema(js);
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500));

	b = ext(js[1]);
	k = only(keys(js[1]));
	@test b.data[:item].data[1] ≈ (js[1][k] - ext.item.c) * ext.item.s;
	@test b.data[:key].data.s[1] == k;

	b = ext(nothing);
	@test nobs(b) == 1
	@test nobs(b.data) == 0
	b = ext(Dict());
	@test nobs(b) == 1
	@test nobs(b.data) == 0

	js = [Dict(randstring(5) => Dict(:a => rand(), :b => randstring(1))) for _ in 1:1000] 
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	b = ext(js[1]);
	k = only(keys(js[1]))
	i = ext.item(js[1][k])
	@test b.data[:item][:b].data.data == i[:b].data.data
	@test b.data[:item][:scalars].data == i[:scalars].data
	@test b.data[:key].data.s[1] == k

	b = ext(nothing);
	@test nobs(b) == 1
	@test nobs(b.data) == 0
	b = ext(Dict());
	@test nobs(b) == 1
	@test nobs(b.data) == 0
end

@testset "Extractor skip empty lists" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b": [], "c": [[], []], "d": 1, "e": {"a": 1}, "f": {"a": []}}""")
	j2 = JSON.parse("""{"a": [{"a":3},{"b":4}], "b": [], "c": [[]], "d": 1, "e": {"a": 2}, "f": {"a": []}}""")
	j3 = JSON.parse("""{"a": [{"a":1},{"b":3}], "b": [], "c": [[], [], [], []], "d": 2, "e": {"a": 3}, "f": {"a": []}}""")
	j4 = JSON.parse("""{"a": [{"a":2},{"b":4}], "b": [], "c": [], "d": 4, "e": {"a": 3}, "f": {"a": []}}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4]);
	ext = suggestextractor(sch)
	@test ext[:a] isa ExtractArray
	@test isnothing(ext[:b])
	@test isnothing(ext[:c])
	@test ext[:d] isa ExtractScalar
	@test ext[:e] isa ExtractDict
	@test isnothing(ext[:f])
end

@testset "Extractor of numbers as strings" begin
	j1 = JSON.parse("""{"a": "1", "b": "a", "c": "1.1", "d": 1.1, "e": "1.2", "f": 1}""")
	j2 = JSON.parse("""{"a": "2", "b": "b", "c": "2", "d": 2, "e": "1.3", "f": 2}""")
	j3 = JSON.parse("""{"a": "3", "b": "c", "c": "2.3", "d": 2.3, "e": "1.4", "f": 3}""")
	j4 = JSON.parse("""{"a": "4", "b": "c", "c": "5", "d": 5, "e": "1.4", "f": 3}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	ext = suggestextractor(sch)

	@test ext[:a].datatype <: Int64
	@test ext[:b].datatype <: String
	@test ext[:c].datatype <: Float64
	@test ext[:d].datatype <: Float64
	@test ext[:e].datatype <: Float64
	@test ext[:f].datatype <: Int64

	ext_j1 = ext(j1)
	ext_j2 = ext(j2)
	ext_j3 = ext(j3)
	ext_j4 = ext(j4)

	@test ext_j1["U"].data ≈ [0, 0, 0, 0, 0]
	@test ext_j2["U"].data ≈ [0.5, 1/3, 3/13, 0.5, 3/13]
	@test ext_j3["U"].data ≈ [1, 2/3, 4/13, 1, 4/13]
	@test ext_j4["U"].data ≈ [1, 1, 1, 1, 1]
end


@testset "testing irregular extractor" begin
	j1 = JSON.parse("""{"a": 4}""")
	j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}}""")
	j3 = JSON.parse("""{"a": [1, 2, 3 , 4]}""")

	sch = schema([j1,j2,j3])
	ext = suggestextractor(sch)
	a = ext(j1)
	@test a.data[1].data[1] == 0
	@test a.data[2].data[:a].data.s[1] == ""
	@test nobs(a.data[3]) == 1
	@test nobs(a.data[3].data) == 0
end
