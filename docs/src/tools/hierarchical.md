```@setup hierarchical
using JsonGrinder
```

# HierarchicalUtils.jl

[`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) uses
[`HierarchicalUtils.jl`](https://github.com/CTUAvastLab/HierarchicalUtils.jl) which brings a lot of
additional features.

```@example hierarchical
using HierarchicalUtils
```

Let's say we have a complex [`Schema`](@ref), which we want to further inspect:

```@repl hierarchical
using JSON
jss = JSON.parse("""[
    { "a": { "b": "foo", "c": [5, 6] }, "d": "bar" },
    { "d": "baz" },
    { "a": { "c": [] }, "b": "foo" }
]""");

sch = schema(jss)
```

In small enough schema, all types of nodes are visible, but it gets more complicated if the schema
does not fit your screen. Let's see how we can use
[`HierarchicalUtils.jl`](https://github.com/CTUAvastLab/HierarchicalUtils.jl) to programmatically
examine `sch`.

First, the whole tree (regardless of the display area size) can be printed with

```@repl hierarchical
printtree(sch)
```

Callling with `trav=true` enables convenient traversal functionality with string indexing:

```@repl hierarchical
printtree(sch, trav=true)
```

This way any element in the schema is swiftly accessible, which may come in handy when inspecting
model parameters or simply deleting/replacing/inserting nodes in the tree. All tree nodes are
accessible by indexing with the traversal code:

```@repl hierarchical
sch["O"]
```

The following two approaches give the same result:

```@repl hierarchical
sch["O"] ≡ sch[:a][:c].items
```

We can iterate over specific nodes in the schema. Let's for example collect all its leaves:

```@repl hierarchical
LeafIterator(sch) |> collect
```

or all [`DictEntry`](@ref) nodes:

```@repl hierarchical
TypeIterator(DictEntry, sch) |> collect
```

We can for example get all traversal codes for nodes matching a given predicate:

```@repl hierarchical
codes = pred_traversal(sch, n -> n.updated ≥ 2)
```

We can even get [`Accessors.jl`](https://github.com/JuliaObjects/Accessors.jl) optics:

```@repl hierarchical
optic = code2lens(sch, "M") |> only
```

which can be used to access the nodes too (as well as many other operations):

```@example hierarchical
using Accessors
```

```@repl hierarchical
getall(sch, optic) |> only
```

!!! ukn "Further reading"
    For the complete showcase of possibilities, refer to the [`HierarchicalUtils.jl`](https://github.com/CTUAvastLab/HierarchicalUtils.jl) manual.
