using Mill, JSON, BSON, Flux, JsonGrinder, Test
using HierarchicalUtils
import HierarchicalUtils: printtree
using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
j4 = JSON.parse("""{"a": 4, "b": {}}""")
j5 = JSON.parse("""{"b": {}}""")
j6 = JSON.parse("""{}""")

sch = schema([j1,j2,j3,j4,j5,j6])

@testset "printtree" begin
	buf = IOBuffer()
    printtree(buf, sch, trav=true)
	str_repr = String(take!(buf))
	@test str_repr ==
"""
[Dict] (updated = 6) [""]
  ├── a: [Scalar - Int64], 1 unique values, updated = 4 ["E"]
  ├── b: [Dict] (updated = 4) ["U"]
  │        ├── a: [List] (updated = 2) ["Y"]
  │        │        └── [Scalar - Int64], 3 unique values, updated = 6 ["a"]
  │        └── b: [Scalar - Int64], 1 unique values, updated = 2 ["c"]
  └── c: [Dict] (updated = 2) ["k"]
           └── a: [Dict] (updated = 2) ["s"]
                    ├── a: [List] (updated = 2) ["u"]
                    │        └── [Scalar - Float64,Int64], 3 unique values, updated = 5 ["v"]
                    └── b: [List] (updated = 2) ["w"]
                             └── [Scalar - Float64,Int64], 3 unique values, updated = 5 ["x"]"""
end

@testset "nnodes" begin
    @test nnodes(sch) == 12
    @test nnodes(sch.childs[:a]) == 1
    @test nnodes(sch.childs[:b]) == 4
    @test nnodes(sch.childs[:c]) == 6
end

@testset "nleafs" begin
    @test nleafs(sch.childs[:a]) + nleafs(sch.childs[:b]) + nleafs(sch.childs[:c]) == nleafs(sch)
end

@testset "children" begin
	@test children(sch) == (a=sch[:a], b=sch[:b], c=sch[:c])
	@test children(sch[:a]) == []
	@test children(sch[:b]) == (a=sch[:b][:a], b=sch[:b][:b])
	@test children(sch[:b][:a]) == (sch[:b][:a].items,)
	@test children(sch[:b][:b]) == []
	@test children(sch[:c]) == (a=sch[:c][:a],)
	@test children(sch[:c][:a]) == (a=sch[:c][:a][:a], b=sch[:c][:a][:b])
	@test children(sch[:c][:a][:a]) == (sch[:c][:a][:a].items,)
	@test children(sch[:c][:a][:b]) == (sch[:c][:a][:b].items,)
end

@testset "nchildren" begin
	@test nchildren(sch) == 3
	@test nchildren(sch[:a]) == 0
	@test nchildren(sch[:b]) == 2
	@test nchildren(sch[:b][:a]) == 1
	@test nchildren(sch[:b][:b]) == 0
	@test nchildren(sch[:c]) == 1
	@test nchildren(sch[:c][:a]) == 2
	@test nchildren(sch[:c][:a][:a]) == 1
	@test nchildren(sch[:c][:a][:b]) == 1
end

@testset "getindex on strings" begin
	@test sch[""] == sch
	@test sch["E"] == sch[:a]
	@test sch["U"] == sch[:b]
	@test sch["Y"] == sch[:b][:a]
	@test sch["a"] == sch[:b][:a].items
	@test sch["c"] == sch[:b][:b]
	@test sch["k"] == sch[:c]
	@test sch["s"] == sch[:c][:a]
	@test sch["u"] == sch[:c][:a][:a]
	@test sch["v"] == sch[:c][:a][:a].items
	@test sch["w"] == sch[:c][:a][:b]
	@test sch["x"] == sch[:c][:a][:b].items
end

@testset "NodeIterator" begin
	@test collect(NodeIterator(sch)) == [sch[""], sch["E"], sch["U"], sch["Y"], sch["a"], sch["c"],
		sch["k"], sch["s"], sch["u"], sch["v"], sch["w"], sch["x"]]
end

@testset "LeafIterator" begin
	@test collect(LeafIterator(sch)) == [sch["E"], sch["a"], sch["c"], sch["v"], sch["x"]]
end

@testset "TypeIterator" begin
	@test collect(TypeIterator{DictEntry}(sch)) == [sch[""], sch["U"], sch["k"], sch["s"]]
end
