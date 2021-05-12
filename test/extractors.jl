using JsonGrinder, JSON, Test, SparseArrays, Flux, Random, HierarchicalUtils
using JsonGrinder: ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector
using Mill: catobs, nobs
using LinearAlgebra

@testset "Testing scalar conversion" begin
	sc = ExtractScalar(Float64,2,3)
	@test all(sc("5").data .== [9])
	@test all(sc(5).data .== [9])
	@test all(sc(nothing).data .== [0])

	@test sc("5", store_input=true).data == sc("5", store_input=false).data
	@test sc("5", store_input=true).metadata == fill("5",1,1)
	@test isnothing(sc("5", store_input=false).metadata)
	@test sc(5, store_input=true).data == sc(5, store_input=false).data
	@test sc(5, store_input=true).metadata == fill(5,1,1)
	@test isnothing(sc(5, store_input=false).metadata)
	@test sc(nothing, store_input=true).data == sc(nothing, store_input=false).data
	@test sc(nothing, store_input=true).metadata == fill(nothing,1,1)
	@test isnothing(sc(nothing, store_input=false).metadata)
end

@testset "Testing array conversion" begin
	sc = ExtractArray(ExtractCategorical(2:4))
	e234 = sc([2,3,4], store_input=false)
	en = sc(nothing, store_input=false)
	e234s = sc([2,3,4], store_input=true)
	ens = sc(nothing, store_input=true)
	@test all(e234.data.data .== Matrix(1.0I, 4, 3))
	@test nobs(en.data) == 0
	@test all(en.bags.bags .== [0:-1])
	@test e234s.data.data == e234.data.data
	@test e234s.data.metadata == [2,3,4]
	@test e234s.data[1].metadata == [2]
	@test e234s.data[2].metadata == [3]
	@test e234s.data[3].metadata == [4]
	@test ens.data.data == en.data.data
	@test ens.data.metadata == []
	@test isnothing(e234.data.metadata)
	@test isnothing(en.data.metadata)

	sc = ExtractArray(ExtractScalar(Float32))
	e234 = sc([2,3,4], store_input=false)
	en = sc(nothing, store_input=false)
	e234s = sc([2,3,4], store_input=true)
	ens = sc(nothing, store_input=true)
	@test all(e234.data.data .== [2 3 4])
	@test nobs(en.data) == 0
	@test all(en.bags.bags .== [0:-1])
	@test e234s.data.data == e234.data.data
	@test e234s.data.metadata == [2 3 4]
	@test e234s.data[1].metadata == fill(2,1,1)
	@test e234s.data[2].metadata == fill(3,1,1)
	@test e234s.data[3].metadata == fill(4,1,1)
	@test ens.data.data == en.data.data
	@test ens.data.metadata == zeros(1,0)
	@test isnothing(e234.data.metadata)
	@test isnothing(en.data.metadata)
end

@testset "Testing feature vector conversion" begin
	sc = ExtractVector(5)
	e1 = sc([1, 2, 2, 3, 4], store_input=false)
	e1s = sc([1, 2, 2, 3, 4], store_input=true)
	e2s = sc([1, 2, 2, 3], store_input=true)
	n1 = sc(missing, store_input=false)
	n1s = sc(missing, store_input=true)
	@test e1.data == [1 2 2 3 4]'
	@test e1.data isa Array{Float32, 2}
	@test e1.data == e1s.data
	@test e1s.metadata == [[1, 2, 2, 3, 4]]
	@test catobs(e1s, e1s).data == [1 1; 2 2; 2 2; 3 3; 4 4]
	@test catobs(e1s, e1s).metadata == [[1, 2, 2, 3, 4], [1, 2, 2, 3, 4]]
	@test catobs(e1s, e1s)[1].data == [1 2 2 3 4]'
	@test catobs(e1s, e1s)[1].metadata == [[1, 2, 2, 3, 4]]
	@test isequal(n1s.metadata, [missing])
	@test isequal(catobs(e1s, n1s).metadata, [[1, 2, 2, 3, 4], missing])
	@test e2s.data == [1 2 2 3 0]'
	@test e2s.metadata == [[1, 2, 2, 3]]

	sc = ExtractVector{Int64}(5)
	@test sc([1, 2, 2, 3, 4]).data ≈ [1, 2, 2, 3, 4]
	@test sc([1, 2, 2, 3, 4]).data isa Array{Int64, 2}
	@test sc([1, 2, 2, 3, 4], store_input=true).data ≈ sc([1, 2, 2, 3, 4], store_input=false).data
	@test sc([1, 2, 2, 3, 4], store_input=true).metadata == [[1, 2, 2, 3, 4]]
	@test sc(nothing).data ≈ [0, 0, 0, 0, 0]
	@test sc(nothing, store_input=true).data ≈ sc(nothing, store_input=false).data
	@test sc(nothing, store_input=true).metadata == [nothing]

	@test !JsonGrinder.extractsmatrix(sc)

	# feature vector longer than expected
	sc = ExtractVector(5)
	@test all(sc([1, 2, 2, 3, 4, 5]).data .== [1, 2, 2, 3, 4])
	@test sc([1, 2, 2, 3, 4, 5], store_input=true).data ≈ sc([1, 2, 2, 3, 4, 5], store_input=false).data
	@test sc([1, 2, 2, 3, 4, 5], store_input=true).metadata == [[1, 2, 2, 3, 4, 5]]
	@test sc([5, 6]).data ≈ [5, 6, 0, 0, 0]
	@test sc(Dict(1=>2)).data ≈ zeros(5)
end

@testset "Testing ExtractDict" begin
	vector = Dict("a" => ExtractScalar(Float64,2,3),"b" => ExtractScalar(Float64))
	other = Dict("c" => ExtractArray(ExtractScalar(Float64,2,3)))
	br = ExtractDict(vector,other)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]), store_input=false)
	a2 = br(Dict("a" => 5, "b" => 7), store_input=false)
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]), store_input=false)
	a1s = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]), store_input=true)
	a2s = br(Dict("a" => 5, "b" => 7), store_input=true)
	a3s = br(Dict("a" => 5, "c" => [1,2,3,4]), store_input=true)
	a4s = br(Dict("c" => [1,2,3,4]), store_input=true)
	a5s = br(Dict("a" => "hello", "b" => "world", "c" => [1,2,3,4]), store_input=true)

	@test all(catobs(a1,a1).data[1].data .==[7 7; 9 9])
	@test all(catobs(a1,a1).data[2].data.data .== [-3 0 3 6 -3 0 3 6])
	@test all(catobs(a1,a1).data[2].bags .== [1:4,5:8])
	@test all(catobs(a1,a1).metadata .== [["b", "a"], ["b", "a"]])

	@test all(catobs(a1,a2).data[1].data .==[7 7; 9 9])
	@test all(catobs(a1,a2).data[2].data.data .== [-3 0 3 6])
	@test all(catobs(a1,a2).data[2].bags .== [1:4,0:-1])
	@test all(catobs(a1,a2).metadata .== [["b", "a"], ["b", "a"]])

	@test all(catobs(a2,a3).data[1].data .==[7 0; 9 9])
	@test all(catobs(a2,a3).data[2].data.data .== [-3 0 3 6])
	@test all(catobs(a2,a3).data[2].bags .== [0:-1,1:4])
	@test all(catobs(a2,a3).metadata .== [["b", "a"], ["b", "a"]])

	@test all(catobs(a1,a3).data[1].data .==[7 0; 9 9])
	@test all(catobs(a1,a3).data[2].data.data .== [-3 0 3 6 -3 0 3 6])
	@test all(catobs(a1,a3).data[2].bags .== [1:4,5:8])
	@test all(catobs(a1,a3).metadata .== [["b", "a"], ["b", "a"]])

	@test catobs(a1,a1).data[1].data == catobs(a1s,a1s).data[1].data
	@test catobs(a1,a1).data[2].data.data == catobs(a1s,a1s).data[2].data.data
	@test catobs(a1s,a1s).data[1].metadata == [7 7; 5 5]
	@test catobs(a1s,a1s).data[2].data.metadata == [1 2 3 4 1 2 3 4]

	@test a1s.data.c.data.metadata == [1 2 3 4]
	@test a1s.data.c.data[1].metadata == fill(1,1,1)
	@test a1s.data.c.data[2].metadata == fill(2,1,1)
	@test a1s.data.c.data[3].metadata == fill(3,1,1)
	@test a1s.data.c.data[4].metadata == fill(4,1,1)

	@test a3s.data.scalars.metadata == reshape([nothing 5],2,1)
	@test a4s.data.scalars.metadata == fill(nothing, 2,1)
	@test a5s.data.scalars.metadata == reshape(["world" "hello"],2,1)

	br = ExtractDict(vector,nothing)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
	a2 = br(Dict("a" => 5, "b" => 7))
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))
	@test all(a1.data .== [7; 9])
	@test all(a2.data .== [7; 9])
	@test all(a3.data .== [0; 9])

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

	vector = Dict(:a => ExtractScalar(Float64,2,3),:b => ExtractScalar(Float64))
	br = ExtractDict(vector,nothing)
	a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
	a2 = br(Dict("a" => 5, "b" => 7))
	a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))
	@test all(a1.data .== [9; 7])
	@test all(a2.data .== [9; 7])
	@test all(a3.data .== [9; 0])
end

@testset "Testing Nested Missing Arrays" begin
	other = Dict("a" => ExtractArray(ExtractScalar(Float32,2,3)),"b" => ExtractArray(ExtractScalar(Float32,2,3)));
	br = ExtractDict(nothing,other)
	a1 = br(Dict("a" => [1,2,3], "b" => [1,2,3,4]), store_input=false)
	a2 = br(Dict("b" => [2,3,4]), store_input=false)
	a3 = br(Dict("a" => [2,3,4]), store_input=false)
	a4 = br(Dict{String,Any}(), store_input=false)
	a1s = br(Dict("a" => [1,2,3], "b" => [1,2,3,4]), store_input=true)
	a2s = br(Dict("b" => [2,3,4]), store_input=true)
	a3s = br(Dict("a" => [2,3,4]), store_input=true)
	a4s = br(Dict{String,Any}(), store_input=true)

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

	@test catobs(a1,a4).data[1].data.data == catobs(a1s,a4s).data[1].data.data
	@test catobs(a1,a4).data[1].bags == catobs(a1s,a4s).data[1].bags
	@test catobs(a1,a4).data[2].data.data == catobs(a1s,a4s).data[2].data.data
	@test catobs(a1,a4).data[2].bags == catobs(a1,a4).data[2].bags

	@test catobs(a1s,a4s).data[1].data.metadata == [1 2 3 4]
	@test catobs(a1s,a4s).data[2].data.metadata == [1 2 3]
	@test a1s.data[1].data.metadata == [1 2 3 4]
	@test a1s.data[2].data.metadata == [1 2 3]
	@test a4s.data[1].data.metadata == zeros(1,0)
	@test a4s.data[2].data.metadata == zeros(1,0)
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
	ea = e("a", store_input=false)
	eb = e("b", store_input=false)
	ez = e("z", store_input=false)
	en = e(nothing, store_input=false)
	eas = e("a", store_input=true)
	ebs = e("b", store_input=true)
	ezs = e("z", store_input=true)
	ens = e(nothing, store_input=true)
	@test ea.data[:] ≈ [1, 0, 0]
	@test eb.data[:] ≈ [0, 1, 0]
	@test ez.data[:] ≈ [0, 0, 1]
	@test en.data[:] ≈ [0, 0, 1]
	@test typeof(ea.data) == Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}
	@test typeof(en.data) == Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}

	@test e(["a", "b"]).data ≈ [0, 0, 1]
	@test mapreduce(e, catobs, ["a", "b"]).data ≈ [1 0; 0 1; 0 0]
	@test typeof(e(["a", "b"]).data) == Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}

	@test isnothing(ExtractCategorical([]))
	e2 = ExtractCategorical(JsonGrinder.Entry(Dict("a"=>1,"c"=>1), 2))
	@test e2("a").data[:] ≈ [1, 0, 0]
	@test e2("c").data[:] ≈ [0, 1, 0]
	@test e2("b").data[:] ≈ [0, 0, 1]
	@test e2(nothing).data[:] ≈ [0, 0, 1]

	@test catobs(ea, eb).data ≈ [1 0; 0 1; 0 0]
	@test catobs(ea.data, eb.data) ≈ [1 0; 0 1; 0 0]
	@test e(Dict(1=>2)).data[:] ≈ [0, 0, 1]

	@test catobs(eas, ebs).data == catobs(ea, eb).data
	@test catobs(eas.data, ebs.data) == catobs(eas.data, ebs.data)
	@test e(Dict(1=>2)).data[:] ≈ [0, 0, 1]

	@test catobs(eas, ebs).metadata == ["a", "b"]
	@test e(Dict(1=>2), store_input=true).metadata == [Dict(1=>2)]
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

	js = [Dict(randstring(5) => Dict(:a => rand(), :b => randstring(1))) for _ in 1:1000]
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	b = ext(js[1])
	k = only(keys(js[1]))
	i = ext.item(js[1][k])
	@test b.data[:item][:b].data.data == i[:b].data.data
	@test b.data[:item][:scalars].data == i[:scalars].data
	@test b.data[:key].data.s[1] == k

	b = ext(nothing)
	@test nobs(b) == 1
	@test nobs(b.data) == 0
	b = ext(Dict())
	@test nobs(b) == 1
	@test nobs(b.data) == 0

	b = ext(js[1], store_input=true)
	@test b.data.data.key.metadata == [first(keys(js[1]))]
	@test b.data.data.item.metadata == [[:a]]

	b = ext(Dict(), store_input=true)
	@test b.data.data.key.metadata == []
	@test b.data.data.item.metadata == []

	b = ext(nothing, store_input=true)
	@test b.data.data.key.metadata == []
	@test b.data.data.item.metadata == []
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

	@test ext[:a].datatype <: Float32
	@test ext[:b].datatype <: String
	@test ext[:c].datatype <: Float32
	@test ext[:d].datatype <: Float32
	@test ext[:e].datatype <: Float32
	@test ext[:f].datatype <: Float32

	ext_j1 = ext(j1, store_input=false)
	ext_j2 = ext(j2, store_input=false)
	ext_j3 = ext(j3, store_input=false)
	ext_j4 = ext(j4, store_input=false)

	@test eltype(ext_j1[:scalars].data) <: Float32
	@test eltype(ext_j2[:scalars].data) <: Float32
	@test eltype(ext_j3[:scalars].data) <: Float32
	@test eltype(ext_j4[:scalars].data) <: Float32

	@test ext_j1["U"].data ≈ [0, 0, 0, 0, 0]
	@test ext_j2["U"].data ≈ [0.5, 1/3, 3/13, 0.5, 3/13]
	@test ext_j3["U"].data ≈ [1, 2/3, 4/13, 1, 4/13]
	@test ext_j4["U"].data ≈ [1, 1, 1, 1, 1]

	ext_j1s = ext(j1, store_input=true)
	ext_j2s = ext(j2, store_input=true)
	ext_j3s = ext(j3, store_input=true)
	ext_j4s = ext(j4, store_input=true)

	@test ext_j1["U"].data == ext_j1s["U"].data
	@test ext_j2["U"].data == ext_j2s["U"].data
	@test ext_j3["U"].data == ext_j3s["U"].data
	@test ext_j4["U"].data == ext_j4s["U"].data

	@test ext_j1s["U"].metadata == reshape([1 "1" 1.1 "1.2" "1.1"], 5, 1)
	@test ext_j2s["U"].metadata == reshape([2 "2" 2 "1.3" "2"], 5, 1)
	@test ext_j3s["U"].metadata == reshape([3 "3" 2.3 "1.4" "2.3"], 5, 1)
	@test ext_j4s["U"].metadata == reshape([3 "4" 5 "1.4" "5"], 5, 1)
end

@testset "Suggest feature vector extraction" begin
	j1 = JSON.parse("""{"a": "1", "b": [1, 2, 3], "c": [1, 2, 3]}""")
	j2 = JSON.parse("""{"a": "2", "b": [2, 2, 3], "c": [1, 2, 3, 4]}""")
	j3 = JSON.parse("""{"a": "3", "b": [3, 2, 3], "c": [1, 2, 3, 4, 5]}""")
	j4 = JSON.parse("""{"a": "4", "b": [2, 3, 4], "c": [1, 2, 3]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	ext = suggestextractor(sch)

	@test ext[:a].datatype <: Float32
	@test ext[:b] isa ExtractVector
	@test ext[:b].n == 3
	@test ext[:c] isa ExtractArray{ExtractScalar{Float32, Float32}}

	ext_j1 = ext(j1, store_input=false)
	ext_j2 = ext(j2, store_input=false)
	ext_j3 = ext(j3, store_input=false)
	ext_j4 = ext(j4, store_input=false)

	ext_j1s = ext(j1, store_input=true)
	ext_j2s = ext(j2, store_input=true)
	ext_j3s = ext(j3, store_input=true)
	ext_j4s = ext(j4, store_input=true)

	@test ext_j1["E"].data ≈ [1, 2, 3]
	@test ext_j2["E"].data ≈ [2, 2, 3]
	@test ext_j3["E"].data ≈ [3, 2, 3]
	@test ext_j4["E"].data ≈ [2, 3, 4]

	@test ext_j1["c"].data ≈ [0 .25 .5]
	@test ext_j2["c"].data ≈ [0 .25 .5 .75]
	@test ext_j3["c"].data ≈ [0 .25 .5 .75 1.]
	@test ext_j4["c"].data ≈ [0 .25 .5]

	for (a,b) in zip([ext_j1, ext_j2, ext_j3, ext_j4], [ext_j1s, ext_j2s, ext_j3s, ext_j4s])
		@test a["E"].data == b["E"].data
		@test a["c"].data == b["c"].data
		@test a["k"].data == b["k"].data
	end

	@test ext_j1s["E"].metadata == [[1, 2, 3]]
	@test ext_j2s["E"].metadata == [[2, 2, 3]]
	@test ext_j3s["E"].metadata == [[3, 2, 3]]
	@test ext_j4s["E"].metadata == [[2, 3, 4]]

	@test ext_j1s["c"].metadata == [1 2 3]
	@test ext_j2s["c"].metadata == [1 2 3 4]
	@test ext_j3s["c"].metadata == [1 2 3 4 5]
	@test ext_j4s["c"].metadata == [1 2 3]
end

@testset "Suggest complex" begin
	JsonGrinder.updatemaxkeys!(1000)
	js = [Dict("a" => rand(), "b" => Dict(randstring(5) => rand()), "c"=>[rand(), rand()], "d"=>[rand() for i in 1:rand(1:10)]) for _ in 1:1000]
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	@test ext[:a].datatype <: Float32
	@test ext[:b] isa JsonGrinder.ExtractKeyAsField
	@test ext[:b].key.datatype <: Float32
	@test ext[:b].item.datatype <: Float32
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

	@test ext_j1.data.data isa Array{Float32,2}
	@test ext_j2.data.data isa Array{Float32,2}
	@test ext_j3.data.data isa Array{Float32,2}
	@test ext_j4.data.data isa Array{Float32,2}
end

@testset "testing irregular extractor" begin
	j1 = JSON.parse("""{"a": 4}""")
	j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}}""")
	j3 = JSON.parse("""{"a": [1, 2, 3 , 4]}""")

	sch = schema([j1,j2,j3])
	ext = suggestextractor(sch)
	a = ext(j1)
	@test a[:e1].data[1] == 0
	@test a[:e2].data[:a].data.s[1] == ""
	@test nobs(a[:e3]) == 1
	# this should be 0, there is problem with handling missing valus
	# todo: make it and issue on github so we have it tracked
	@test_broken nobs(a[:e3].data) == 0
	@test nobs(a[:e3].data) == 1
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
	@test e1["U"].data ≈ [0]
	@test e2["U"].data ≈ [1]
	@test e3["U"].data ≈ [0.7]
	@test e4["U"].data ≈ [0.5]
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

	@test buf_printtree(sch) ==
    """
    [Dict] (updated = 7)
      └── a: [MultiEntry] (updated = 7)
               ├── 1: [Scalar - String], 3 unique values, updated = 3
               ├── 2: [Scalar - Float64,Int64], 2 unique values, updated = 2
               ├── 3: [List] (updated = 1)
               │        └── [Scalar - Int64], 5 unique values, updated = 5
               └── 4: [Dict] (updated = 1)
                        └── Sylvanas is the worst warchief ever: [Scalar - String], 1 unique values, updated = 1"""

	@test buf_printtree(ext) ==
    """
	Dict
	  └── a: MultiRepresentation
	           ├── e1: FeatureVector with 5 items
	           ├── e2: Dict
	           │         └── Sylvanas is the worst warchief ever: String
	           └── e3: Float32"""

	e1 = ext(j1)
	e2 = ext(j2)
	e3 = ext(j3)
	e4 = ext(j4)
	e5 = ext(j5)
	@test e1["k"].data ≈ [0]
	@test e2["k"].data ≈ [0.375]
	@test e3["k"].data ≈ [0.525]
	@test e4["k"].data ≈ [1.0]
	@test e5["k"].data ≈ [0.875]

	@test buf_printtree(e1) ==
	"""
	ProductNode
	  ├── e1: ArrayNode(5, 1)
	  ├── e2: ArrayNode(2053, 1)
	  └── e3: ArrayNode(1, 1)"""
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
	@test e1["U"].data ≈ [0]
	@test e2["U"].data ≈ [0.5]
	@test e3["U"].data ≈ [1.0]
	@test e4["U"].data ≈ [0]
	@test e5["U"].data ≈ [0]

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
	@test ext(f) == ext(nothing)

	@test ext(f, store_input=true) != ext(nothing, store_input=true)
	@test ext(f, store_input=true).data == ext(nothing, store_input=true).data
	@test ext(a, store_input=true).metadata == ["a"]
	@test ext(b, store_input=true).metadata == ["b"]
	@test ext(c, store_input=true).metadata == [""]
	@test ext(d, store_input=true).metadata == ["d"]
	@test ext(e, store_input=true).metadata == [""]
	@test ext(f, store_input=true).metadata == [5.2]
	@test ext(nothing, store_input=true).metadata == [nothing]
	#todo: add tests for all extractors for store_input=true
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
	e = AuxiliaryExtractor(e2, (ext, sample; store_input=false)->ext(String(sample), store_input=store_input))

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
    BagNode with 1 bag(s)
      └── ArrayNode(1, 2)"""
end
