using JsonGrinder, JSON, Test, SparseArrays, Flux, Random, HierarchicalUtils
using JsonGrinder: ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector
using JsonGrinder: extractempty
using Mill
using Mill: catobs, nobs, MaybeHotMatrix
using LinearAlgebra

function misequals(a, b)
	for i in 1:length(a)
		ismissing(b[i]) && !ismissing(a[i]) && return(false)
		ismissing(a[i]) && !ismissing(b[i]) && return(false)
		!ismissing(a[i]) && a[i] != b[i] && return(false)
	end
	return(true)
end

@testset "Testing ExtractScalar" begin
	sc = ExtractScalar(Float64,2,3)
	@test all(sc("5").data .== [9])
	@test all(sc(5).data .== [9])
	@test all(sc(nothing).data .=== [missing])
	@test all(sc(missing).data .=== [missing])
	@test nobs(sc(missing)) == 1
	@test nobs(sc(nothing)) == 1
	@test sc(extractempty).data isa Matrix{Float64}
	@test nobs(sc(extractempty)) == 0
	@test nobs(sc(5)) == 1

	sc = ExtractScalar(Float32, 0.5, 4.0)
	@test sc(1).data isa Matrix{Float32}
	@test sc(extractempty).data isa Matrix{Float32}
end


@testset "ExtractCategorical" begin
	e = ExtractCategorical(["a","b"])
	@test e("a").data ≈ [1, 0, 0]
	@test e("b").data ≈ [0, 1, 0]
	@test e("z").data ≈ [0, 0, 1]
	@test all(e(nothing).data |> collect .=== [missing, missing, missing])
	@test all(e(missing).data |> collect .=== [missing, missing, missing])
	@test typeof(e("a").data) == MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}
	@test typeof(e(nothing).data) == MaybeHotMatrix{Missing,Array{Missing,1},Int64,Missing}
	@test typeof(e(missing).data) == MaybeHotMatrix{Missing,Array{Missing,1},Int64,Missing}
	@test e(extractempty).data isa MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}
	@test nobs(e(extractempty)) == 0

	@test e(["a", "b"]).data ≈ [1 0; 0 1; 0 0]
	@test all(e(["a", missing]).data |> collect .=== [true missing; false missing; false missing])
	@test all(e(["a", missing, "x"]).data |> collect .=== [true missing false; false missing false; false missing true])
	@test typeof(e(["a", "b"]).data) == MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}
	@test typeof(e(["a", "b", nothing]).data) == MaybeHotMatrix{Union{Missing, Int64},Array{Union{Missing, Int64},1},Int64,Union{Missing, Bool}}

	@test isnothing(ExtractCategorical([]))
	e2 = ExtractCategorical(JsonGrinder.Entry(Dict("a"=>1,"c"=>1), 2))
	@test e2("a").data ≈ [1, 0, 0]
	@test e2("c").data ≈ [0, 1, 0]
	@test e2("b").data ≈ [0, 0, 1]
	@test all(e2(nothing).data |> collect .=== [missing, missing, missing])
	@test all(e2(missing).data |> collect .=== [missing, missing, missing])

	@test catobs(e("a"), e("b")).data ≈ [1 0; 0 1; 0 0]
	@test catobs(e("a").data, e("b").data) ≈ [1 0; 0 1; 0 0]
	@test all(e(Dict(1=>2)).data |> collect .=== [missing, missing, missing])

	@test nobs(e("a")) == 1
	@test nobs(e("b")) == 1
	@test nobs(e("z")) == 1
	@test nobs(e(nothing)) == 1
	@test nobs(e(missing)) == 1
	@test nobs(e(missing).data) == 1
	@test nobs(e([missing, nothing])) == 2
	@test nobs(e([missing, nothing, "a"])) == 3


end


@testset "Testing array conversion" begin
	sc = ExtractArray(ExtractCategorical(2:4))
	@test all(sc([2,3,4]).data.data .== Matrix(1.0I, 4, 3))
	@test nobs(sc(nothing).data) == 0
	@test sc(nothing).data.data isa MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}
	@test nobs(sc(nothing).data.data) == 0
	@test all(sc(nothing).bags.bags .== [0:-1])

	@test nobs(sc(extractempty).data.data) == 0
	@test nobs(sc(extractempty).data) == 0
	@test isempty(sc(extractempty).bags.bags)
	@test sc(extractempty).data.data isa MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}

	sc = ExtractArray(ExtractScalar(Float32))
	@test all(sc([2,3,4]).data.data .== [2 3 4])
	@test nobs(sc(nothing).data) == 0
	@test all(sc(nothing).bags.bags .== [0:-1])

	@test nobs(sc(extractempty).data.data) == 0
	@test nobs(sc(extractempty).data) == 0
	@test isempty(sc(extractempty).bags.bags)
	@test sc(extractempty).data.data isa Matrix{Float32}

	@test sc(nothing).data.data isa Matrix{Float32}
end

@testset "Testing feature vector conversion" begin
	sc = ExtractVector(5)
	@test sc([1, 2, 2, 3, 4]).data isa Matrix
	@test all(sc([1, 2, 2, 3, 4]).data .== [1, 2, 2, 3, 4])
	@test sc([1, 2, 2, 3, 4]).data isa Array{Float32, 2}
	@test sc(extractempty).data isa Matrix{Float32}
	@test nobs(sc(extractempty).data) == 0

	sc = ExtractVector{Int64}(5)
	@test all(sc([1, 2, 2, 3, 4]).data .== [1, 2, 2, 3, 4])
	@test sc([1, 2, 2, 3, 4]).data isa Array{Int64, 2}
	@test sc(nothing).data isa Matrix
	@test all(sc(nothing).data .=== missing)
	@test sc(extractempty).data isa Matrix{Int64}
	@test nobs(sc(extractempty).data) == 0


	# feature vector longer than expected
	sc = ExtractVector{Float32}(5)
	@test all(sc([1, 2, 2, 3, 4, 5]).data .== [1, 2, 2, 3, 4])
	@test typeof(sc([1, 2, 3, 4, 5]).data) == Array{Float32,2}
	@test sc([5, 6]).data[1:2] ≈ [5, 6]
	@test typeof(sc([1, 2]).data) == Array{Union{Missing,Float32},2}
	@test sc([1, 2]).data isa Matrix
	@test all(sc([5, 6]).data[3:5] .=== missing)
	@test all(sc(Dict(1=>2)).data .=== missing)
end

@testset "Testing ExtractDict" begin
	dict = Dict("a" => ExtractScalar(Float64,2,3),
				"b" => ExtractScalar(Float64),
				"c" => ExtractArray(ExtractScalar(Float64,2,3)))
	br = ExtractDict(dict)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
	a2 = br(Dict("a" => 5, "b" => 7))
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))

	@test catobs(a1,a1)[:a].data ≈ [9 9]
	@test catobs(a1,a1)[:b].data ≈ [7 7]
	@test catobs(a1,a1)[:c].data.data ≈  [-3 0 3 6 -3 0 3 6]
	@test all(catobs(a1,a1)[:c].bags .== [1:4,5:8])

	@test catobs(a1,a2)[:a].data ≈ [9 9]
	@test catobs(a1,a2)[:b].data ≈ [7 7]
	@test catobs(a1,a2)[:c].data.data ≈ [-3 0 3 6]
	@test all(catobs(a1,a2)[:c].bags .== [1:4,0:-1])

	@test catobs(a2,a3)[:a].data ≈ [9 9]
	@test misequals(catobs(a2,a3)[:b].data, [7.0 missing])
	@test catobs(a2,a3)[:c].data.data ≈ [-3 0 3 6]
	@test all(catobs(a2,a3)[:c].bags .== [0:-1,1:4])

	@test catobs(a1,a3)[:a].data ≈ [9 9]
	@test misequals(catobs(a1,a3)[:b].data, [7.0 missing])
	@test catobs(a1,a3)[:c].data.data ≈ [-3 0 3 6 -3 0 3 6]
	@test all(catobs(a1,a3)[:c].bags .== [1:4,5:8])

	@test a1[:a].data ≈ [9]
	@test a1[:b].data ≈ [7]
	@test a2[:a].data ≈ [9]
	@test a2[:b].data ≈ [7]
	@test a3[:a].data ≈ [9]
	@test misequals(a3[:b].data, [missing])

	@test a1[:c].data.data ≈ [-3 0 3 6]
	@test all(a1[:c].bags .== [1:4])

	@test a3[:c].data.data ≈ [-3 0 3 6]
	@test all(a3[:c].bags .== [1:4])
	@test catobs(a3,a3)[:c].data.data ≈ [-3 0 3 6 -3 0 3 6]
	@test all(catobs(a3,a3)[:c].bags .== [1:4,5:8])

	a4 = br(extractempty)
	@test nobs(a4[:a]) == 0
	@test a4[:a].data isa Matrix{Float64}
	@test nobs(a4[:b]) == 0
	@test a4[:b].data isa Matrix{Float64}
	@test nobs(a4[:c]) == 0
	@test nobs(a4[:c].data) == 0
	@test a4[:c].data.data isa Matrix{Float64}
end

@testset "Testing Nested Missing Arrays" begin
	dict = Dict("a" => ExtractArray(ExtractScalar(Float32,2,3)),
		"b" => ExtractArray(ExtractScalar(Float32,2,3)))
	br = ExtractDict(dict)
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

	@test all(a4.data[2].data.data isa Array{Float32,2})
	a4 = br(extractempty)
	@test nobs(a4[:a]) == 0
	@test nobs(a4[:a].data) == 0
	@test a4[:a].data.data isa Matrix{Float32}
	@test nobs(a4[:b]) == 0
	@test nobs(a4[:b].data) == 0
	@test a4[:b].data.data isa Matrix{Float32}
end

@testset "ExtractOneHot" begin
	samples = ["{\"name\": \"a\", \"count\" : 1}",
		"{\"name\": \"b\", \"count\" : 2}",]
	vs = JSON.parse.(samples)

	e = ExtractOneHot(["a","b"], "name", "count")
	@test e(vs).data[:] ≈ [1, 2, 0]
	@test e(nothing).data[:] ≈ [0, 0, 0]
	@test e(missing).data[:] ≈ [0, 0, 0]
	@test e(vs).data isa SparseMatrixCSC{Float32,Int64}
	@test e(nothing).data isa SparseMatrixCSC{Float32,Int64}
	@test e(missing).data isa SparseMatrixCSC{Float32,Int64}
	@test e(extractempty).data isa SparseMatrixCSC{Float32,Int64}
	@test nobs(e(extractempty)) == 0
	@test nobs(e(extractempty).data) == 0

	e = ExtractOneHot(["a","b"], "name", nothing)
	@test e(vs).data[:] ≈ [1, 1, 0]
	@test e(nothing).data[:] ≈ [0, 0, 0]
	@test e(missing).data[:] ≈ [0, 0, 0]
	@test typeof(e(vs).data) == SparseMatrixCSC{Float32,Int64}
	@test typeof(e(nothing).data) == SparseMatrixCSC{Float32,Int64}
	@test typeof(e(missing).data) == SparseMatrixCSC{Float32,Int64}
	vs = JSON.parse.(["{\"name\": \"c\", \"count\" : 1}"])
	@test e(vs).data[:] ≈ [0, 0, 1]
	@test typeof(e(vs).data) == SparseMatrixCSC{Float32,Int64}
	@test e(extractempty).data isa SparseMatrixCSC{Float32,Int64}
	@test nobs(e(extractempty)) == 0
	@test nobs(e(extractempty).data) == 0
end

@testset "Extractor of keys as field" begin
	JsonGrinder.updatemaxkeys!(1000)
	js = [Dict(randstring(5) => rand()) for _ in 1:1000]
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	b = ext(js[1])
	k = only(keys(js[1]))
	@test b.data[:item].data[1] ≈ (js[1][k] - ext.item.c) * ext.item.s
	@test b.data[:key].data.s[1] == k

	b = ext(nothing)
	@test nobs(b) == 1
	@test nobs(b.data) == 0
	b = ext(Dict())
	@test nobs(b) == 1
	@test nobs(b.data) == 0

	b = ext(extractempty)
	@test nobs(b) == 0
	@test nobs(b.data) == 0
	@test nobs(b.data[:item]) == 0
	@test b.data[:item].data isa Matrix{Float32}
	@test nobs(b.data[:key]) == 0
	@test b.data[:key].data isa Mill.NGramMatrix{String,Array{String,1},Int64}


	js = [Dict(randstring(5) => Dict(:a => rand(), :b => randstring(1))) for _ in 1:1000]
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	b = ext(js[1])
	k = only(keys(js[1]))
	i = ext.item(js[1][k])
	@test b.data[:item][:a].data == i[:a].data
	@test b.data[:item][:b].data ==i[:b].data
	@test b.data[:key].data.s[1] == k

	b = ext(nothing)
	@test nobs(b) == 1
	@test nobs(b.data) == 0
	b = ext(Dict())
	@test nobs(b) == 1
	@test nobs(b.data) == 0
end


@testset "equals and hash test" begin
	other1 = Dict(
		"a" => ExtractArray(ExtractScalar(Float64,2,3)),
		"b" => ExtractArray(ExtractScalar(Float64,2,3)),
		"c" => ExtractCategorical(["a","b"]),
		"d" => ExtractVector(4),
	)
	br1 = ExtractDict(other1)
	other11 = Dict(
		"a" => ExtractArray(br1),
		"b" => ExtractScalar(Float64,2,3),
	)
	br11 = ExtractDict(other11)

	other2 = Dict(
		"a" => ExtractArray(ExtractScalar(Float64,2,3)),
		"b" => ExtractArray(ExtractScalar(Float64,2,3)),
		"c" => ExtractCategorical(["a","b"]),
		"d" => ExtractVector(4),
	)
	br2 = ExtractDict(other2)
	other22 = Dict("a" => ExtractArray(br2), "b" => ExtractScalar(Float64,2,3))
	br22 = ExtractDict(other22)

	@test hash(br11) === hash(br22)
	@test hash(br11) !== hash(br1)
	@test hash(br11) !== hash(br2)
	@test hash(br1) === hash(br2)

	@test br11 == br22
	@test br11 != br1
	@test br11 != br2
	@test br1 == br2
end

@testset "Extractor skip empty lists" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b": [], "c": [[], []], "d": 1, "e": {"a": 1}, "f": {"a": []}}""")
	j2 = JSON.parse("""{"a": [{"a":3},{"b":4}], "b": [], "c": [[]], "d": 1, "e": {"a": 2}, "f": {"a": []}}""")
	j3 = JSON.parse("""{"a": [{"a":1},{"b":3}], "b": [], "c": [[], [], [], []], "d": 2, "e": {"a": 3}, "f": {"a": []}}""")
	j4 = JSON.parse("""{"a": [{"a":2},{"b":4}], "b": [], "c": [], "d": 4, "e": {"a": 3}, "f": {"a": []}}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
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

	@test ext[:a] isa ExtractCategorical
	@test ext[:b] isa ExtractString
	@test ext[:c] isa ExtractCategorical
	@test ext[:d] isa ExtractScalar{Float32}
	@test ext[:e] isa ExtractCategorical
	@test ext[:f] isa ExtractScalar{Float32}

	ext_j1 = ext(j1)
	ext_j2 = ext(j2)
	ext_j3 = ext(j3)
	ext_j4 = ext(j4)

	@test eltype(ext_j1[:a].data) <: Bool
	@test eltype(ext_j1[:b].data) <: Int64
	@test eltype(ext_j1[:c].data) <: Bool
	@test eltype(ext_j1[:d].data) <: Float32
	@test eltype(ext_j1[:e].data) <: Bool
	@test eltype(ext_j1[:f].data) <: Float32

	@test eltype(ext_j2[:a].data) <: Bool
	@test eltype(ext_j2[:b].data) <: Int64
	@test eltype(ext_j2[:c].data) <: Bool
	@test eltype(ext_j2[:d].data) <: Float32
	@test eltype(ext_j2[:e].data) <: Bool
	@test eltype(ext_j2[:f].data) <: Float32

	@test eltype(ext_j3[:a].data) <: Bool
	@test eltype(ext_j3[:b].data) <: Int64
	@test eltype(ext_j3[:c].data) <: Bool
	@test eltype(ext_j3[:d].data) <: Float32
	@test eltype(ext_j3[:e].data) <: Bool
	@test eltype(ext_j3[:f].data) <: Float32

	@test eltype(ext_j4[:a].data) <: Bool
	@test eltype(ext_j4[:b].data) <: Int64
	@test eltype(ext_j4[:c].data) <: Bool
	@test eltype(ext_j4[:d].data) <: Float32
	@test eltype(ext_j4[:e].data) <: Bool
	@test eltype(ext_j4[:f].data) <: Float32

	@test ext_j1["U"].data ≈ [0]
	@test ext_j2["U"].data ≈ [3/13]
	@test ext_j3["U"].data ≈ [4/13]
	@test ext_j4["U"].data ≈ [1]

	# todo: add tests for Mill that it's correctly reflected in model
	m = reflectinmodel(sch, ext)
	@test buf_printtree(m) == """
	ProductModel ↦ ArrayModel(Dense(42, 10))
	  ├── a: ArrayModel(Dense(5, 10))
	  ├── b: ArrayModel(Dense(2053, 10))
	  ├── c: ArrayModel(Dense(5, 10))
	  ├── d: ArrayModel(identity)
	  ├── e: ArrayModel(Dense(4, 10))
	  └── f: ArrayModel(identity)"""
end

@testset "Suggest feature vector extraction" begin
	j1 = JSON.parse("""{"a": "1", "b": [1, 2, 3], "c": [1, 2, 3]}""")
	j2 = JSON.parse("""{"a": "2", "b": [2, 2, 3], "c": [1, 2, 3, 4]}""")
	j3 = JSON.parse("""{"a": "3", "b": [3, 2, 3], "c": [1, 2, 3, 4, 5]}""")
	j4 = JSON.parse("""{"a": "4", "b": [2, 3, 4], "c": [1, 2, 3]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	ext = suggestextractor(sch)

	@test ext[:a] isa ExtractCategorical
	@test ext[:b] isa ExtractVector
	@test ext[:b].n == 3
	@test ext[:c] isa ExtractArray{ExtractScalar{Float32}}

	ext_j1 = ext(j1)
	ext_j2 = ext(j2)
	ext_j3 = ext(j3)
	ext_j4 = ext(j4)

	@test ext_j1["U"].data ≈ [1, 2, 3]
	@test ext_j2["U"].data ≈ [2, 2, 3]
	@test ext_j3["U"].data ≈ [3, 2, 3]
	@test ext_j4["U"].data ≈ [2, 3, 4]

	@test ext_j1["s"].data ≈ [0 .25 .5]
	@test ext_j2["s"].data ≈ [0 .25 .5 .75]
	@test ext_j3["s"].data ≈ [0 .25 .5 .75 1.]
	@test ext_j4["s"].data ≈ [0 .25 .5]
end

@testset "Suggest complex" begin
	JsonGrinder.updatemaxkeys!(1000)
	js = [Dict("a" => rand(), "b" => Dict(randstring(5) => rand()), "c"=>[rand(), rand()], "d"=>[rand() for i in 1:rand(1:10)]) for _ in 1:1000]
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	@test ext[:a] isa ExtractScalar{Float32}
	@test ext[:b] isa JsonGrinder.ExtractKeyAsField
	@test ext[:b].key isa ExtractString
	@test ext[:b].item isa ExtractScalar{Float32}
	@test ext[:c] isa ExtractVector
	@test ext[:c].n == 2
	@test ext[:d] isa ExtractArray
end

@testset "Extractor typed missing bags" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [1, 2]}""")
	j3 = JSON.parse("""{"a": [1, 2, 3]}""")
	j4 = JSON.parse("""{"a": [1, 2, 3, 4]}""")
	j5 = JSON.parse("""{"a": [1, 2, 3, 4, 5]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	ext = suggestextractor(sch)

	ext_j1 = ext(j1)
	ext_j2 = ext(j2)
	ext_j3 = ext(j3)
	ext_j4 = ext(j4)

	@test ext_j1[:a].data.data isa Array{Float32,2}
	@test ext_j2[:a].data.data isa Array{Float32,2}
	@test ext_j3[:a].data.data isa Array{Float32,2}
	@test ext_j4[:a].data.data isa Array{Float32,2}
end

@testset "testing irregular extractor" begin
	j1 = JSON.parse("""{"a": 4}""")
	j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}}""")
	j3 = JSON.parse("""{"a": [1, 2, 3, 4]}""")
	j4 = JSON.parse("""{"a": 5}""")
	j5 = JSON.parse("""{"a": 3}""")

	sch = schema([j1,j2,j3,j4,j5])
	ext = suggestextractor(sch)
	a = ext(j1)
	@test a[:a][:e1].data[1] == 0.5
	@test ismissing(a[:a][:e2].data[:a].data.s[1])
	@test nobs(a[:a][:e3]) == 1
	@test nobs(a[:a][:e3].data) == 1
end

@testset "Mixed scalar extraction" begin
	j1 = JSON.parse("""{"a": "1"}""")
	j2 = JSON.parse("""{"a": 4}""")
	j3 = JSON.parse("""{"a": "3.1"}""")
	j4 = JSON.parse("""{"a": 2.5}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	sch_hash = hash(sch)
	ext = suggestextractor(sch)
	@test sch_hash == hash(sch)	# testing that my entry parkour does not modify schema
	@test nchildren(ext[:a]) == 1

	e1 = ext(j1)
	e2 = ext(j2)
	e3 = ext(j3)
	e4 = ext(j4)
	@test e1["k"].data ≈ [0]
	@test e2["k"].data ≈ [1]
	@test e3["k"].data ≈ [0.7]
	@test e4["k"].data ≈ [0.5]
end

@testset "Mixed scalar extraction with other types" begin
	j1 = JSON.parse("""{"a": "1"}""")
	j2 = JSON.parse("""{"a": 2.5}""")
	j3 = JSON.parse("""{"a": "3.1"}""")
	j4 = JSON.parse("""{"a": 5}""")
	j5 = JSON.parse("""{"a": "4.5"}""")
	j6 = JSON.parse("""{"a": [1, 2, 3, 4, 5]}""")
	j7 = JSON.parse("""{"a": {"Sylvanas is the worst warchief ever": "yes"}}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4, j5, j6, j7])
	ext = suggestextractor(sch)

	# @test_broken buf_printtree(sch) ==
 #    """
 #    [Dict] (updated = 7)
 #      └── a: [MultiEntry] (updated = 7)
 #               ├── 1: [Scalar - String], 3 unique values, updated = 3
 #               ├── 2: [Scalar - Float64,Int64], 2 unique values, updated = 2
 #               ├── 3: [List] (updated = 1)
 #               │        └── [Scalar - Int64], 5 unique values, updated = 5
 #               └── 4: [Dict] (updated = 1)
 #                        └── Sylvanas is the worst warchief ever: [Scalar - String], 1 unique values, updated = 1"""

	# @test_broken buf_printtree(ext) ==
 #    """
	# Dict
	#   └── a: MultiRepresentation
	#            ├── e1: FeatureVector with 5 items
	#            ├── e2: Dict
	#            │         └── Sylvanas is the worst warchief ever: String
	#            └── e3: Float32"""

	e1 = ext(j1)
	e2 = ext(j2)
	e3 = ext(j3)
	e4 = ext(j4)
	e5 = ext(j5)
	@test e1["s"].data ≈ [0]
	@test e2["s"].data ≈ [0.375]
	@test e3["s"].data ≈ [0.525]
	@test e4["s"].data ≈ [1.0]
	@test e5["s"].data ≈ [0.875]

	@test_broken buf_printtree(e1) ==
	"""
	ProductNode with 1 obs
	  └── a: ProductNode with 1 obs
	           ├── e1: ArrayNode(5×1 Array, Float32) with 1 obs
	           ├── e2: ProductNode with 1 obs
	           │         └── Sylvanas is the worst warchief ever: ArrayNode(2053×1 NGramMatrix, Int64) with 1 obs
	           └── e3: ArrayNode(1×1 Array, Float32) with 1 obs"""
end

@testset "mixing numeric and non-numeric strings" begin
	j1 = JSON.parse("""{"a": "hello"}""")
	j2 = JSON.parse("""{"a": "4"}""")
	j3 = JSON.parse("""{"a": 5}""")
	j4 = JSON.parse("""{"a": 3.0}""")
	j5 = JSON.parse("""{"a": [1, 2, 3, 4, 5]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4, j5])
	ext = suggestextractor(sch)

	@test buf_printtree(sch) ==
	"""
	[Dict] (updated = 5)
	  └── a: [MultiEntry] (updated = 5)
	           ├── 1: [Scalar - String], 2 unique values, updated = 2
	           ├── 2: [Scalar - Float64,Int64], 2 unique values, updated = 2
	           └── 3: [List] (updated = 1)
	                    └── [Scalar - Int64], 5 unique values, updated = 5"""

	@test buf_printtree(ext) ==
	"""
	Dict
	  └── a: MultiRepresentation
	           ├── e1: String
	           ├── e2: Float32
	           └── e3: FeatureVector with 5 items"""

	e1 = ext(j1)
	e2 = ext(j2)
	e3 = ext(j3)
	e4 = ext(j4)
	e5 = ext(j5)
	@test all(e1["k"].data .=== [missing])
	@test e2["k"].data ≈ [0.5]
	@test e3["k"].data ≈ [1.0]
	@test e4["k"].data ≈ [0.0]
	@test all(e5["k"].data .=== [missing])

	@test hash(ext) !== hash(suggestextractor(JsonGrinder.schema([j1, j2, j4, j5])))
end

@testset "empty string and substring" begin
	a, b, c = split("a b ", " ")
	d = "d"
	e = ""
	f = 5.2
	@test a isa SubString{String}
	@test b isa SubString{String}
	@test c isa SubString{String}
	@test d isa String
	@test e isa String
	@test f isa AbstractFloat
	@test c == ""
	ext = JsonGrinder.extractscalar(AbstractString)
	@test SparseMatrixCSC(ext(c).data) == SparseMatrixCSC(ext(e).data)
	@test all(ext(f).data.s .=== ext(nothing).data.s)
end

@testset "key as field" begin
	j1 = JSON.parse("""{"a": 1}""")
	j2 = JSON.parse("""{"b": 2.5}""")
	j3 = JSON.parse("""{"c": 3.1}""")
	j4 = JSON.parse("""{"d": 5}""")
	j5 = JSON.parse("""{"e": 4.5}""")
	j6 = JSON.parse("""{"f": 5}""")
	sch = JsonGrinder.schema([j1, j2, j3, j4, j5, j6])
	e = JsonGrinder.key_as_field(sch, NamedTuple(), path = "")
	@test e isa JsonGrinder.ExtractKeyAsField

	e2 = JsonGrinder.key_as_field(sch, NamedTuple(), path = "")
	@test hash(e) === hash(e2)
	@test e == e2
end

@testset "AuxiliaryExtractor HUtils" begin
	e2 = ExtractCategorical(["a","b"])
	e = AuxiliaryExtractor(e2, (ext, sample)->ext(String(sample)))

	@test e("b") == e(:b)
	@test e("b").data ≈ [0, 1, 0]
	@test e(:b).data ≈ [0, 1, 0]

    @test buf_printtree(e) ==
	"""
    Auxiliary extractor with
      └── Categorical d = 3"""
end

@testset "Skipping single dict key" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [1, 2]}""")
	j3 = JSON.parse("""{"a": [1, 2, 3]}""")
	j4 = JSON.parse("""{"a": [1, 2, 3, 4]}""")
	j5 = JSON.parse("""{"a": [1, 2, 3, 4, 5]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4, j5])
	ext = suggestextractor(sch)

	@test buf_printtree(ext) ==
	"""
	Dict
	  └── a: Array of
	           └── Float32"""

	ext_j2 = ext(j2)
    @test buf_printtree(ext_j2) ==
    """
	ProductNode with 1 obs
	  └── a: BagNode with 1 obs
	           └── ArrayNode(1×2 Array, Float32) with 2 obs"""
		   # todo: add more tests for integration with Mill to make sure it's propagated well
end
