# Schema

The schema helps to understand the structure of JSON files, by which we understand the types of nodes (Dict, Array, Values) and frequency of occurences of values and lengths of arrays. The schema also holds statistics about how many times the node has been presented. All these informations are taken into the account by `suggestextractor` function, which takes a schema and using few reasonable heuristic suggest an extractor, which convert jsons to Mill structure. The schema might be also useful for formats with enforced schema to collect statistics on leafs.

The main function to create schema is `schema`, which accepts a list of (unparsed) JSONs and producing schema. Schema can be always updated to reflect new JSONs and allow streaming by `update!` function. Moreover, `schema` accepts an optional argument a function converting an item of and array to a JSON. Thism a function creating schema from all jsons in a dictionaty can look like
```julia
schema(readdir("jsons", join = true)) do s
	open(s,"r") do fio
		read(fio, String)
	end |> JSON.parse
end
```
A schema can be further updated by calling function `update!(sch, json).` Schemas can be merged using the overloaded `merge` function, which facilitates distributed creation of schema. Schema can be saved in html by `generate_html` allowing their interactive exploration.

## Implementation details
Statistics are collected in a hierarchical structure reflecting the structured composed of `DictEntry`, `ArrayEntry`, and `Entry.` These structures reflects the those in JSON: `Dict`, `Array`, and Value (either `String` or a `Number`). Sometimes, data are stored in JSONs not adhering to a stable schema, which happens if one key have childs of different type. An example of such would be 
```json
{"a" = [1,2,3]}
{"a" = {b = 1}}
{"a" = "hello"}
```
For these cases, we have introduced additional `Entry`, a `MultiEntry,` but we discourage to rely on this feature and recommend to adapts JSONs to have stable schema (if possible).

Each subtype of `JSONEntry` implements and `update!` function, which recursively update of the schema.

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
