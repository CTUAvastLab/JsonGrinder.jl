using Mill, JSON, BSON, Flux, JsonGrinder, Test
using HierarchicalUtils
import HierarchicalUtils: NodeType, childrenfields, children, childrenstring, InnerNode, SingletonNode, LeafNode, printtree

using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

@testset "basic behavior testing" begin
    # todo: load some schema and extractor
    # otestovat printtree, nnodes, nleafs, encode_traversal a treba iteratory

    j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
    j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
    j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
    j4 = JSON.parse("""{"a": 4, "b": {}}""")
    j5 = JSON.parse("""{"b": {}}""")
    j6 = JSON.parse("""{}""")

    sch = schema([j1,j2,j3,j4,j5,j6])
    NodeType(typeof(sch))
    methods(noderepr)
    printtree(sch)
end
