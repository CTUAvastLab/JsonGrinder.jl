using Mill, JSON, BSON, Flux, JsonGrinder, Test
using HierarchicalUtils
import HierarchicalUtils: NodeType, children, InnerNode, LeafNode, printtree
using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],    "b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
j2 = JSON.parse("""{"a": 4, "c": {"a":{"a":[2,3], "b":[5,6]}}}""")
j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3,4],  "b": 1}}""")
j4 = JSON.parse("""{"a": 4, "b": {}}""")
j5 = JSON.parse("""{"b": {}}""")
j6 = JSON.parse("""{}""")

sch = schema([j1,j2,j3,j4,j5,j6])
ext = suggestextractor(sch)

@testset "printtree" begin
    @test buf_printtree(ext, trav=true) ==
    """
    Dict [""]
      ├── a: Float32 ["E"]
      ├── b: Dict ["U"]
      │        ├── a: Array of ["Y"]
      │        │        └── Float32 ["a"]
      │        └── b: Float32 ["c"]
      └── c: Dict ["k"]
               └── a: Dict ["s"]
                        ├── a: Array of ["u"]
                        │        └── Float32 ["v"]
                        └── b: Array of ["w"]
                                 └── Float32 ["x"]"""
end

@testset "nnodes" begin
    @test nnodes(ext) == 12
    @test nnodes(ext[:a]) == 1
    @test nnodes(ext[:b]) == 4
    @test nnodes(ext[:c]) == 6
end

@testset "nleafs" begin
    @test nleafs(ext[:a]) + nleafs(ext[:b]) + nleafs(ext[:c]) == nleafs(ext)
end

@testset "children" begin
    @test children(ext) == (a=ext[:a], b=ext[:b], c=ext[:c])
    @test children(ext[:a]) == ()
    @test children(ext[:b]) == (a=ext[:b][:a], b=ext[:b][:b])
    @test children(ext[:b][:a]) == (ext[:b][:a].item,)
    @test children(ext[:b][:b]) == ()
    @test children(ext[:c]) == (a=ext[:c][:a],)
    @test children(ext[:c][:a]) == (a=ext[:c][:a][:a], b=ext[:c][:a][:b])
    @test children(ext[:c][:a][:a]) == (ext[:c][:a][:a].item,)
    @test children(ext[:c][:a][:b]) == (ext[:c][:a][:b].item,)
end

@testset "nchildren" begin
    @test nchildren(ext) == 3
    @test nchildren(ext[:a]) == 0
    @test nchildren(ext[:b]) == 2
    @test nchildren(ext[:b][:a]) == 1
    @test nchildren(ext[:b][:b]) == 0
    @test nchildren(ext[:c]) == 1
    @test nchildren(ext[:c][:a]) == 2
    @test nchildren(ext[:c][:a][:a]) == 1
    @test nchildren(ext[:c][:a][:b]) == 1
end

@testset "getindex on strings" begin
    @test ext[""] == ext
    @test ext["E"] == ext[:a]
    @test ext["U"] == ext[:b]
    @test ext["Y"] == ext[:b][:a]
    @test ext["a"] == ext[:b][:a].item
    @test ext["c"] == ext[:b][:b]
    @test ext["k"] == ext[:c]
    @test ext["s"] == ext[:c][:a]
    @test ext["u"] == ext[:c][:a][:a]
    @test ext["v"] == ext[:c][:a][:a].item
    @test ext["w"] == ext[:c][:a][:b]
    @test ext["x"] == ext[:c][:a][:b].item
end

@testset "NodeIterator" begin
    @test collect(NodeIterator(ext)) == [ext[""], ext["E"], ext["U"], ext["Y"], ext["a"], ext["c"],
        ext["k"], ext["s"], ext["u"], ext["v"], ext["w"], ext["x"]]
end

@testset "LeafIterator" begin
    @test collect(LeafIterator(ext)) == [ext["E"], ext["a"], ext["c"], ext["v"], ext["x"]]
end

@testset "TypeIterator" begin
    @test collect(TypeIterator(ext, ExtractArray)) == [ext["Y"], ext["u"], ext["w"]]
end

@testset "show" begin
    e = ExtractCategorical(["a","b"])
    buf = IOBuffer()
    printtree(buf, e)
    str_repr = String(take!(buf))
    @test str_repr == """Categorical d = 3"""

    e = ExtractOneHot(["a","b"], "name", nothing)
    buf = IOBuffer()
    printtree(buf, e)
    str_repr = String(take!(buf))
    @test str_repr == """OneHot d = 3"""

    other = Dict("a" => ExtractArray(ExtractScalar(Float64,2,3)),"b" => ExtractArray(ExtractScalar(Float64,2,3)));
    br = ExtractDict(nothing,other)
    @test buf_printtree(br, trav=true) ==
    """
    Dict [""]
      ├── a: Array of ["E"]
      │        └── Float64 ["M"]
      └── b: Array of ["U"]
               └── Float64 ["c"]"""

    vector = Dict("a" => ExtractScalar(Float64,2,3),"b" => ExtractScalar(Float64))
    other = Dict("c" => ExtractArray(ExtractScalar(Float64,2,3)))
    br = ExtractDict(vector,other)
    @test buf_printtree(br, trav=true) ==
    """
    Dict [""]
      ├── a: Float64 ["E"]
      ├── b: Float64 ["U"]
      └── c: Array of ["k"]
               └── Float64 ["s"]"""

    other1 = Dict("a" => ExtractArray(ExtractScalar(Float64,2,3)),"b" => ExtractArray(ExtractScalar(Float64,2,3)))
    br1 = ExtractDict(nothing,other1)
    other = Dict("a" => ExtractArray(br1), "b" => ExtractScalar(Float64,2,3))
    br = ExtractDict(nothing,other)
    @test buf_printtree(br, trav=true) ==
    """
    Dict [""]
      ├── a: Array of ["E"]
      │        └── Dict ["M"]
      │              ├── a: Array of ["O"]
      │              │        └── Float64 ["P"]
      │              └── b: Array of ["Q"]
      │                       └── Float64 ["R"]
      └── b: Float64 ["U"]"""
end
