```@setup hierarchical
using Mill, JSON
```

# HierarchicalUtils.jl
JsonGrinder.jl uses [HierarchicalUtils.jl](https://github.com/Sheemon7/HierarchicalUtils.jl) which brings a lot of additional features.

```@example hierarchical
using HierarchicalUtils
```

Let's say we gave complex schema and we want to find type instabilities.

After creating the schema as
```@repl hierarchical
j1 = JSON.parse("""{"a": 4, "b": "birb"}""")
j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}, "b": "bird"}""")
j3 = JSON.parse("""{"a": [1, 2, 3, "hi"], "b": "word"}""")

sch = schema([j1, j2, j3])
```

In small enough schema, you can immediately see all types of nodes, but it gets more complicated if the schema does not fit your screen.

We can find irregularities a.k.a. MultiEntry by running

```@repl hierarchical
TypeIterator(JsonGrinder.MultiEntry, sch) |> collect
filter(e->sch[e] isa JsonGrinder.MultiEntry, list_traversal(sch))
```

which tells us there are 2 multientries, but does not tell us where they are.

Using this
```@repl hierarchical
filter(e->sch[e] isa JsonGrinder.MultiEntry, list_traversal(sch))
```

we can see that `sch["E"]` and `sch["S"]` are indeed MultiEntry.

<!--
todo: přidat příklad s HUtils a 2 jsony, hledáním MultiEntry podle TypeIteratoru
 and take inspiration from HUtils section in Mill.jl

 ## Printing

 For instance, `Base.show` with `text/plain` MIME calls `HierarchicalUtils.printtree`:

 ```@repl hierarchical
 ds = BagNode(ProductNode((BagNode(ArrayNode(randn(4, 10)),
                                   [1:2, 3:4, 5:5, 6:7, 8:10]),
                           ArrayNode(randn(3, 5)),
                           BagNode(BagNode(ArrayNode(randn(2, 30)),
                                           [i:i+1 for i in 1:2:30]),
                                   [1:3, 4:6, 7:9, 10:12, 13:15]),
                           ArrayNode(randn(2, 5)))),
              [1:1, 2:3, 4:5])
 printtree(ds; htrunc=3)
 ```

 This can be used to print a non-truncated version of a model:

 ```@repl hierarchical
 printtree(ds)
 ```

 ## Traversal encoding

 Callling with `trav=true` enables convenient traversal functionality with string indexing:

 ```@repl hierarchical
 m = reflectinmodel(ds)
 printtree(m; trav=true)
 ```

 This way any node in the model tree is swiftly accessible, which may come in handy when inspecting model parameters or simply deleting/replacing/inserting nodes to tree (for instance when constructing adversarial samples). All tree nodes are accessible by indexing with the traversal code:.

 ```@repl hierarchical
 m["Y"]
 ```

 The following two approaches give the same result:

 ```@repl hierarchical
 m["Y"] === m.im.ms[1]
 ```

 ## Counting functions

 Other functions provided by `HierarchicalUtils.jl`:

 ```@repl hierarchical
 nnodes(ds)
 nleafs(ds)
 NodeIterator(ds) |> collect
 NodeIterator(ds, m) |> collect
 LeafIterator(ds) |> collect
 TypeIterator(BagModel, m) |> collect
 PredicateIterator(x -> nobs(x) ≥ 10, ds) |> collect
 ```

 For the complete showcase of possibilites, refer to [HierarchicalUtils.jl](https://github.com/CTUAvastLab/HierarchicalUtils.jl) and [this notebook](https://github.com/CTUAvastLab/HierarchicalUtils.jl/blob/master/examples/mill_integration.ipynb) -->
