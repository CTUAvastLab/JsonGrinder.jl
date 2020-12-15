# Schema

The goal of the schema is to discover the structure of JSON files. By structure we inderstand the specification of types of internal nodes (Dict, Array, Values). Besides, the schema holds statistics about how many times the node has been presented and also frequency of appereances of values in leafs. The latter is a useful information for deciding, how to represent (convert) valus in leafs to tensor. The schema might be usefol for formats with enforced schema to collect statistics on leafs.

`JsonGrinder.schema` collect statistics from a set of JSONs. Statistics are collected in a hierarchical structure reflecting the structured composed of `DictEntry`, `ArrayEntry`, and `Entry.` These structures reflects the those in JSON: `Dict`, `Array`, and Value (either String or a Number). Sometimes, data are stored in JSONs not adhering to a stable schema, which happens if one key have childs of different type. An example of such would be 
```json
{"a" = [1,2,3]}
{"a" = {b = 1}}
{"a" = "hello"}
```
For these cases, we have introduced additional `Entry`, a `MultiEntry,` but we discourage to rely on this feature and recommend to adapts JSONs to have stable schema (if possible).

### Entry
```julia
mutable struct Entry{T} <: JSONEntry
	counts::Dict{T,Int}
	updated::Int
end
```
`Entry` keeps information about leaf-values (e.g. `"a" = 3`) (strings or numbers) in JSONs. It consists of two statistics
* `updated` counts how many times the leaf with a given key was observed,
* `counts` counts how many times a particular value of the leaf was observed.

To keep `counts` from becoming too large, once its length exceeds `updatemaxkeys` (default 10 000), then the new values will be dropped. This value can be changed by `updatemaxkeys!`, but of course the new limit will be applied to newly processed values.

## ArrayEntry
```julia
mutable struct ArrayEntry <: JSONEntry
	items
	l::Dict{Int,Int}
	updated::Int
end
```
`ArrayEntry` keeps information about arrays (e.g. `"a" = [1,2,3,4]`). Statistics about individual items of the array are deffered to `item`, which can be `<:JSONEntry`. `l` stores keeps histogram of lengts of arrays, and `updated` is keep number of times this key has been observed.

## DictEntry
```julia
mutable struct DictEntry <: JSONEntry
	childs::Dict{Symbol, Any}
	updated::Int
end
```
deferes all statistics about its children to them, and the only statistic is again a counter `updated,` about observation times.

## MultiEntry
```julia
mutable struct MultiEntry <: JSONEntry
	childs::Vector{JSONEntry}
	updated::Int
end
```
is a failsave for cases, where the schema is not stable. For example in following two JSONs
```json
{"a" = "Hello"}
{"a" = ["Hello"," world"]}
```
the type of a value of a key `"a"` is `String`, whereas in the second it is `"Vector"`. The JsonGrinder will deal with this by first creating an `Entry`, since the value is scalar, and upon encountering the second JSON, it will replace `Entry` with `MultiEntry` having `Entry` and `ArrayEntry` as childs (this is the reason why entries are declared mutable). 

*While JsonGrinder can deal with non-stable jsons, it is strongly discouraged as it might have negative effect on the performance.*

## Extra functions

While schema can be printed to REPL, it can contain quite a lot of information. Therefore `JsonGrinder.generate_html` exports it to HTML, where parts can be expanded at wish.

```@docs
JsonGrinder.generate_html
```

```@docs
JsonGrinder.merge
```

Schema supports merging using `Base.merge`, which facilitates paralel computation of schemas. An example might be
```
ThreadsX.mapreduce(schema, merge, Iterators.partition(jsons, div(length(jsons), Threads.nthreads())))
```

```@docs 
JsonGrinder.prune_json
```

```@docs 
JsonGrinder.updatemaxkeys!
```

```@docs 
JsonGrinder.updatemaxlen!
```
