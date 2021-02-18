# HierarchicalUtils.jl
JsonGrinder.jl uses [HierarchicalUtils.jl](https://github.com/Sheemon7/HierarchicalUtils.jl) which brings a lot of additional features.

```@example hierarchical
using HierarchicalUtils
```

Let's say we gave complex schema and we want to find type instabilities.

After creating the schema as
```@repl hierarchical
using JSON, JsonGrinder
j1 = JSON.parse("""{"a": 4, "b": "birb"}""")
j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}, "b": "bird"}""")
j3 = JSON.parse("""{"a": [1, 2, 3, "hi"], "b": "word"}""")

sch = schema([j1, j2, j3])
```

In small enough schema, you can immediately see all types of nodes, but it gets more complicated if the schema does not fit your screen. Let's see how we can leverage `HierarchicalUtils` to programmatically examine shema.

This can be used to print a non-truncated version of a model:

```@repl hierarchical
printtree(sch)
```

Callling with `trav=true` enables convenient traversal functionality with string indexing:

```@repl hierarchical
printtree(sch, trav=true)
```

This way any element in the schema is swiftly accessible, which may come in handy when inspecting model parameters or simply deleting/replacing/inserting nodes to tree (for instance when constructing adversarial samples). All tree nodes are accessible by indexing with the traversal code:

```@repl hierarchical
sch["N"]
```

The following two approaches give the same result:

```@repl hierarchical
sch["N"] === sch.childs[:a][2][:a]
```

We can even search for specific elements in schema. Let's examine occurrences of irregularities a.k.a. MultiEntry by running

```@repl hierarchical
TypeIterator(JsonGrinder.MultiEntry, sch) |> collect
```

which tells us there are 2 multientries, but does not tell us where they are.

Using this
```@repl hierarchical
filter(e->sch[e] isa JsonGrinder.MultiEntry, list_traversal(sch))
```

we can see that `sch["E"]` and `sch["S"]` are indeed MultiEntry, but we don't have easy way to see where they are in schema.

```@repl hierarchical
using Mill
lenses = [only(code2lens(sch, e)) for e in list_traversal(sch) if sch[e] isa JsonGrinder.MultiEntry]
```

gives us lenses to access them and also information about path from root.
`@lens` is part of [Setfield.jl](https://github.com/jw3126/Setfield.jl) package which allows creating lenses which let you easily describe and apply accessors for hierarchical structures.

```@repl hierarchical
get(sch, lenses[1])
```

returns the first `MultiEntry` and

```@repl hierarchical
get(sch, lenses[2])
```

returns the second one.

For the complete showcase of possibilities, refer to [HierarchicalUtils.jl](https://github.com/CTUAvastLab/HierarchicalUtils.jl) and [this notebook](https://github.com/CTUAvastLab/HierarchicalUtils.jl/blob/master/examples/mill_integration.ipynb)
