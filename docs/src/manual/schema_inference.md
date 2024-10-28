```@setup schema
using JsonGrinder
```

# [Schema inference](@id manual_schema)

The *schema* helps to understand the structure of JSON documents and stores some basic statistics of
values present in the dataset. All this information is later taken into the account in the
[`suggestextractor`](@ref) function, which takes a schema and using few reasonable heuristic,
suggests a suitable extractor for converting JSONs to
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures.

In this simple example, we start with a dataset of three JSON documents:

```@example schema
using JSON
```

```@repl schema
jss = JSON.parse.([
   """{ "a": "Hello", "b": { "c": 1, "d": [] } }""",
   """{ "b": { "c": 1, "d": [1, 2, 3] } }""",
   """{ "a": "World", "b": { "c": 2, "d": [1, 3] } }""",
]);
jss[1]
```

The main function for creating schema is `schema`, which accepts an array documents and
produces a [`Schema`](@ref):

```@repl schema
sch = schema(jss[1:2])
```

This schema might already come handy for quick statistical insight into the dataset at hand, which
we discuss further below.

Schema can be always updated with another document with the [`update!`](@ref) function:

```@repl schema
update!(sch, jss[3]);
sch
```

## Schema merging

Lastly, it is also possible to merge two or more schemas together with [`Base.merge`](@ref) and
[`Base.merge!`](@ref). It is thus possible to easily parallelize schema inference, merging together
individual (sub)schemas as follows:

```@repl schema
sch1 = schema(jss[1:2])
sch2 = schema(jss[3:3])
merge(sch1, sch2)
```

or inplace merge into `sch1`:

```@repl schema
merge!(sch1, sch2);
sch1
```

## Advanced

Statistics are collected in a hierarchical structure reflecting the structured composed of
[`DictEntry`](@ref), [`ArrayEntry`](@ref), and [`LeafEntry`](@ref). These structures are direct
counterparts to those in JSON: `Dict`, `Array`, and `Value`.

In this example we will load larger dataset of JSON documents (available [here](https://github.com/CTUAvastLab/JsonGrinder.jl/tree/master/docs/src/manual/json_examples.json)):

```@repl schema
jss = JSON.parsefile("json_examples.json");
jss[1]
```

and compute the schema:

```@repl schema
sch = schema(jss)
```

To save space, hierarchical structures like schema and extractor are not shown in full in REPL. To
inspect the full schema, we can use `printtree` from
[`HierarchicalUtils.jl`](https://github.com/CTUAvastLab/HierarchicalUtils.jl). We use

- `vtrunc=3`, which only shows at most 3 children of each node in the tree, and
- `trav=true`, which also shows traversal codes of individual nodes.

```@repl schema
printtree(sch; vtrunc=3, trav=true)
```

Traversal codes (strings printed at the end of rows) can be used to access individual elements
of the schema.

```@repl schema
sch["JQ"]
sch["sc"]
```


As indicated in the displayed tree, [`LeafEntry`](@ref) accessible as `sch["JQ"]` was updated 3
times in input documents. On the other hand, [`LeafEntry`](@ref) accessible as `sch["sc"]` was
updated 12 times, each time with a different value.

!!! ukn "Empty arrays"
    Note that for example the [`ArrayEntry`](@ref) accessible as `sch["AU"]` has been updated 22 times,
    but doesn't have any children. This is because on path with keys `"abstract"` and `"cite_spans"`, 
    we have seen 22 arrays, but all were empty.

To learn more about the [`HierarchicalUtils.jl`](https://github.com/CTUAvastLab/HierarchicalUtils.jl)
package, check also [this section](@ref HierarchicalUtils.jl) of docs, or [this
section](https://CTUAvastLab.github.io/Mill.jl/stable/tools/hierarchical/) in the
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) docs.

## Schema parameters

It may happen that values in leaves of the documents are too unique. Saving all values might quickly
become too memory demanding. [`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) thus
works with [`JsonGrinder.max_values`](@ref) parameter. Once the number of unique values in one leaf
exceeds this parameter, [`schema`](@ref) will no longer remember new appearing values in this leaf.
This behavior might be relevant when calling [`suggestextractor`](@ref), especially with
the `categorical_limit` argument.

Similarly, [`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) also shortens strings
that are too long before saving them to schema. This can be governed with the
[`JsonGrinder.max_string_length`](@ref) parameter.

## Preprocessing

Sometimes, input JSON documents do not adhere to a stable schema, which for example happens if one
key has children of multiple different types in different documents. An example would be:

```@repl schema
jss = JSON.parse.([
    """ {"a": [1, 2, 3] } """,
    """ {"a": { "b": 1 } } """,
    """ {"a": "hello" } """
])
```

In these cases the schema creation fails indicating what went wrong:

```@repl schema
schema(jss)
```

Should this happen, we recommend to deal with such cases by suitable preprocessing.

### Mapping paths

Assume that input documents contain information about port numbers, some of which are encoded as
integers and some of which as strings:

```@repl schema
jss = [
    """ {"ports": [70, 80, 443], "protocol": "TCP" } """,
    """ {"ports": ["22", "80", "500"], "protocol": "UDP" } """,
]
```
```@repl schema
schema(JSON.parse, jss)
```

We recommend to deal with these cases using optic approach from
[`Accessors.jl`](https://juliaobjects.github.io/Accessors.jl/stable/) (and possibly also from
[`AccessorsExtra.jl`](https://github.com/JuliaAPlavin/AccessorsExtra.jl)). We can use
`Accessors.modify` to modify the problematic paths, turning all into `String`s:

```@example schema
using Accessors
```
```@repl schema
f = js -> Accessors.modify(string, js, @optic _["ports"][∗])
f.(JSON.parse.(jss))
schema(f ∘ JSON.parse, jss)
```

or parsing them as `Integer`s:

```@repl schema
schema(jss) do doc
    js = JSON.parse(doc)
    Accessors.modify(x -> x isa Integer ? x : parse(Int, x), js, @optic _["ports"][∗])
end
```

!!! ukn "Writing `∗`"
    Asterisk for selecting all elements of the array (`∗`) is not the standard star (`*`), but is
    written as `\ast<TAB>` in Julia REPL, see also [`Accessors.jl`
    docstrings](https://juliaobjects.github.io/Accessors.jl/stable/docstrings/).

We can also get rid of this path completely with `Accessors.delete`:

```@repl schema
schema(jss) do doc
    Accessors.delete(JSON.parse(doc), @optic _["ports"])
end
```

If [`JSON3`](https://github.com/quinnj/JSON3.jl) is used for parsing, it uses `Symbol`s for keys
in objects instead of `String`s so make sure to use `Symbol`s:

```@example schema
using JSON3
```
```@repl schema
Accessors.delete(JSON3.read(""" {"port": 1} """), @optic _["port"])
Accessors.delete(JSON3.read(""" {"port": 1} """), @optic _[:port])
```

### Null values

In the current version, [`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) does not
support `null` values in JSON documents (represented as `nothing` in Julia):

```@repl schema
schema(JSON.parse, [
    """ {"a": null } """
])
```
```@repl schema
schema(JSON.parse, [
    """ {"a": [1, null, 3] } """
])
```
```@repl schema
schema(JSON.parse, [
    """ {"a": {"b": null} } """
])
```

These values usually do not carry any relevant information, therefore, as the error suggests, the most straighforward and easiest solution is to filter them out using [`remove_nulls`](@ref) function:

```@repl schema
schema(remove_nulls ∘ JSON.parse, [
    """ {"a": null } """
])
```
```@repl schema
schema(remove_nulls ∘ JSON.parse, [
    """ {"a": [1, null, 3] } """
])
```
```@repl schema
schema(remove_nulls ∘ JSON.parse, [
    """ {"a": {"b": null} } """
])
```
