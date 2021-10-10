using Mill, JSON, Flux, JsonGrinder, Test
using HierarchicalUtils
import HierarchicalUtils: printtree
using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
j2 = JSON.parse("""{"a": 4, "c": {"a":{"a":[2,3],"b":[5,6]}}}""")
j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
j4 = JSON.parse("""{"a": 4, "b": {}}""")
j5 = JSON.parse("""{"b": {}}""")
j6 = JSON.parse("""{}""")

sch = schema([j1,j2,j3,j4,j5,j6])

@testset "printtree" begin
    @test buf_printtree(sch, trav=true) ==
    """
    [Dict] [""] \t# updated = 6
      ├── a: [Scalar - Int64], 1 unique values ["E"] \t# updated = 4
      ├── b: [Dict] ["U"] \t# updated = 4
      │        ├── a: [List] ["Y"] \t# updated = 2
      │        │        └── [Scalar - Int64], 3 unique values ["a"] \t# updated = 6
      │        └── b: [Scalar - Int64], 1 unique values ["c"] \t# updated = 2
      └── c: [Dict] ["k"] \t# updated = 2
               └── a: [Dict] ["s"] \t# updated = 2
                        ├── a: [List] ["u"] \t# updated = 2
                        │        └── [Scalar - Float64,Int64], 3 unique values ["v"] \t# updated = 5
                        └── b: [List] ["w"] \t# updated = 2
                                 └── [Scalar - Float64,Int64], 3 unique values ["x"] \t# updated = 5
    """
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
    @test children(sch) == [:a=>sch[:a], :b=>sch[:b], :c=>sch[:c]]
    @test children(sch[:a]) == ()
    @test children(sch[:b]) == [:a=>sch[:b][:a], :b=>sch[:b][:b]]
    @test children(sch[:b][:a]) == (sch[:b][:a].items,)
    @test children(sch[:b][:b]) == ()
    @test children(sch[:c]) == [:a=>sch[:c][:a]]
    @test children(sch[:c][:a]) == [:a=>sch[:c][:a][:a], :b=>sch[:c][:a][:b]]
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
    @test collect(TypeIterator(DictEntry, sch)) == [sch[""], sch["U"], sch["k"], sch["s"]]
end

@testset "print with empty lists" begin
    j1 = JSON.parse("""{"a": 4, "c": { "a": {"a":[1,2,3],"b":[4,5,6]}}, "d":[]}""",inttype=Float64)
    j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}, "d":[]}""")
    j3 = JSON.parse("""{"a": 4, "d":[]}""")
    j4 = JSON.parse("""{"a": 4, "d":[]}""")
    j5 = JSON.parse("""{"d":[]}""")
    j6 = JSON.parse("""{}""")

    sch = schema([j1,j2,j3,j4,j5,j6])

    @test buf_printtree(sch, trav=true) ==
    """
    [Dict] [""] \t# updated = 6
      ├── a: [Scalar - Int64], 1 unique values ["E"] \t# updated = 4
      ├── c: [Dict] ["U"] \t# updated = 2
      │        └── a: [Dict] ["c"] \t# updated = 2
      │                 ├── a: [List] ["e"] \t# updated = 2
      │                 │        └── [Scalar - Float64,Int64], 3 unique values ["f"] \t# updated = 5
      │                 └── b: [List] ["g"] \t# updated = 2
      │                          └── [Scalar - Float64,Int64], 3 unique values ["h"] \t# updated = 5
      └── d: [Empty List] ["k"] \t# updated = 5
               └── Nothing ["s"]
    """
end

@testset "print with multi entry" begin
    j1 = JSON.parse("""{"a": 4, "c": { "a": {"a":[1,2,3],"b":[4,5,6]}}, "d":[]}""",inttype=Float64)
    j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}, "d":[]}""")
    j3 = JSON.parse("""{"a": 4, "c": 5, "d":[]}""")
    j4 = JSON.parse("""{"a": 4, "c": 6.5, "d":[]}""")
    j5 = JSON.parse("""{"c": ["Oh", "Hi", "Mark"], "d":[]}""")
    j6 = JSON.parse("""{}""")

    sch = schema([j1,j2,j3,j4,j5,j6])

    @test buf_printtree(sch, trav=true) ==
    """
    [Dict] [""] \t# updated = 6
      ├── a: [Scalar - Int64], 1 unique values ["E"] \t# updated = 4
      ├── c: [MultiEntry] ["U"] \t# updated = 5
      │        ├── 1: [Dict] ["Y"] \t# updated = 2
      │        │        └── a: [Dict] ["a"] \t# updated = 2
      │        │                 ├── a: [List] ["aU"] \t# updated = 2
      │        │                 │        └── [Scalar - Float64,Int64], 3 unique values ["ak"] \t# updated = 5
      │        │                 └── b: [List] ["b*"] \t# updated = 2
      │        │                          └── [Scalar - Float64,Int64], 3 unique values ["bE"] \t# updated = 5
      │        ├── 2: [Scalar - Float64,Int64], 2 unique values ["c"] \t# updated = 2
      │        └── 3: [List] ["g"] \t# updated = 1
      │                 └── [Scalar - String], 3 unique values ["i"] \t# updated = 3
      └── d: [Empty List] ["k"] \t# updated = 5
               └── Nothing ["s"]
    """
end

@testset "print with multi entry 2" begin
    j1 = JSON.parse("""{"a": "4"}""",inttype=Float64)
    j2 = JSON.parse("""{"a": ["It's", "over", 9000]}""")
    j3 = JSON.parse("""{"a": 5.5}""")
    j4 = JSON.parse("""{"a": "5.5"}""")
    j5 = JSON.parse("""{"a": "Oh, Hi Mark"}""")
    j6 = JSON.parse("""{"a": 4}""")

    sch = schema([j1,j2,j3,j4,j5,j6])

    @test buf_printtree(sch, trav=true) ==
    """
    [Dict] [""] \t# updated = 6
      └── a: [MultiEntry] ["U"] \t# updated = 6
               ├── 1: [Scalar - String], 3 unique values ["c"] \t# updated = 3
               ├── 2: [List] ["k"] \t# updated = 1
               │        └── [MultiEntry] ["o"] \t# updated = 3
               │              ├── 1: [Scalar - String], 2 unique values ["p"] \t# updated = 2
               │              └── 2: [Scalar - Int64], 1 unique values ["q"] \t# updated = 1
               └── 3: [Scalar - Float64,Int64], 2 unique values ["s"] \t# updated = 2
    """
end


@testset "Base.show" begin
    j1 = JSON.parse("""{"a": "4"}""",inttype=Float64)
    j2 = JSON.parse("""{"a": ["It's", "over", 9000]}""")
    j3 = JSON.parse("""{"a": 5.5}""")
    j4 = JSON.parse("""{"a": "5.5"}""")
    j5 = JSON.parse("""{"a": "Oh, Hi Mark"}""")
    j6 = JSON.parse("""{"a": 4}""")

    sch = schema([j1,j2,j3,j4,j5,j6])
    methods(printtree)
    @test repr(sch) == "DictEntry"
    @test repr("text/plain", sch) == buf_printtree(sch; trav=false, htrunc=3, vtrunc=20, breakline=false)
    repr(Dict(1=>2))
end
