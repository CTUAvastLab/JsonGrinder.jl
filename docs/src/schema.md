# Schema

The schema helps to understand the structure of JSON files, by which we understand the types of nodes (Dict, Array, Values) and frequency of occurrences of values and lengths of arrays. The schema also holds statistics about how many times the node has been present. All this information is taken into the account by `suggestextractor` function, which takes a schema and using few reasonable heuristic, suggests an extractor, which convert jsons to Mill structure. The schema might be also useful for formats with enforced schema to collect statistics on leaves.

The main function to create schema is `schema`, which accepts a list of (unparsed) JSONs and producing schema. Schema can be always updated to reflect new JSONs and allow streaming by `update!` function. Moreover, `schema` accepts an optional argument, a function converting an element of an array to a JSON. This a function creating schema from all jsons in a dictionary can look like

```julia
schema(readdir("jsons", join = true)) do s
	open(s,"r") do fio
		read(fio, String)
	end |> JSON.parse
end
```

`schema` function has following default behavior: If passed array of strings, it consideres them to be filenames and passes each element as an argument to `JSON.parse` function.

A schema can be further updated by calling function `update!(sch, json).` Schemas can be merged using the overloaded `merge` function, which facilitates distributed creation of schema following map-reduce paradigm.

Schema can be saved in html by `generate_html` allowing their interactive exploration.
Calling `generate_html(filename, sch)` will generate self-contained file with HTML+CSS+JS.
The generated visualization is interactive, implemented using VanillaJS.

Schema assumes the root of each JSON is dictionary.

## Implementation details
Statistics are collected in a hierarchical structure reflecting the structured composed of `DictEntry`, `ArrayEntry`, and `Entry.` These structures reflect those in JSON: `Dict`, `Array`, and Value (either `String` or a `Number`). Sometimes, data are stored in JSONs not adhering to a stable schema, which happens if one key have children of different type. An example of such would be
```json
{"a": [1,2,3]}
{"a": {"b": 1}}
{"a": "hello"}
```

For such cases, we have introduced additional `JSONEntry`, a `MultiEntry,` but we discourage to rely on this feature and recommend to adapt JSONs to have stable schema (if possible).
This can be achieved by modifying each sample before it's passed into the schema.

Each subtype of `JSONEntry` implements the `update!` function, which recursively updates the schema.

### Entry
```julia
mutable struct Entry{T} <: JSONEntry
	counts::Dict{T,Int}
	updated::Int
end
```
`Entry` keeps information about leaf-values (e.g. `"a" = 3`) (strings or numbers) in JSONs. It consists of two statistics
* `updated` counts how many times the leaf in a given position in JSON was observed,
* `counts` counts how many times a particular value of that leaf was observed.

To keep `counts` dictionary from becoming too large, once its length exceeds `JsonGrinder.max_keys` (default is `10_000`), then the new values will be dropped. This value can be changed by `JsonGrinder.updatemaxkeys!(some_higher_value)`, but of course the new limit will be applied only to newly processed values, so it's advised to set it in the beginning of your scripts.

### ArrayEntry
```julia
mutable struct ArrayEntry <: JSONEntry
	items
	l::Dict{Int,Int}
	updated::Int
end
```
`ArrayEntry` keeps information about arrays (e.g. `"a": [1,2,3,4]`). Statistics about individual items of the array are deferred to `item`, which can be `<:JSONEntry`. `l` keeps histogram of lengths of arrays, and `updated` is number of times an array has been observed in particular place in JSON.

### DictEntry
```julia
mutable struct DictEntry <: JSONEntry
	childs::Dict{Symbol, Any}
	updated::Int
end
```

defers all statistics about its children to them, and the only statistic is again a counter `updated` about number of observations.
Fields `childs` contains all keys which were observed in specific Dictionary and their corresponding `<:JSONEntry` values with statistics about values observed under given key.

### MultiEntry
```julia
mutable struct MultiEntry <: JSONEntry
	childs::Vector{JSONEntry}
	updated::Int
end
```

is a failsafe for cases, where the schema is not stable. For example in following two JSONs
```json
{"a": "Hello"}
{"a": ["Hello"," world"]}
```
the type of a value of a key `"a"` is `String`, whereas in the second it is `"Vector"`. The JsonGrinder will deal with this by first creating an `Entry`, since the value is scalar, and upon encountering the second JSON, it will replace `Entry` with `MultiEntry` having `Entry` and `ArrayEntry` as children (this is the reason why entries are declared mutable).

*While JsonGrinder can deal with non-stable jsons, it is strongly discouraged as it might have negative effect on the performance.*

Usefulness of such feature comes into play also when you don't know if your schema is stable or not.
In that case, you can calculate the schema, and then search for `MultiEntry` nodes.

### Illustrative example

Let's say we have following jsons. We take them and create a schema.
```julia
using JSON, JsonGrinder
jsons = [
       """{"a": "Hello", "b":{"c":1, "d":1}}""",
       """{"a": ["Hi", "Julia"], "b":{"c":1, "d":[1,2,3]}}""",
       """{"a": "World", "b":{"c":2, "d":2}}""",
]
sch = schema(JSON.parse, jsons)
```

you can visualize schema by
```julia
julia> display(sch)
[Dict] (updated = 3)
  ├── a: [MultiEntry] (updated = 3)
  │        ├── 1: [Scalar - String], 2 unique values, updated = 2
  │        └── 2: [List] (updated = 1)
  │                 ⋮
  └── b: [Dict] (updated = 3)
           ├── c: [Scalar - Int64], 2 unique values, updated = 3
           └── d: [MultiEntry] (updated = 3)
                    ⋮
```
which shows only reasonable part.

To see whole schema, we can use `printtree(ds; htrunc=Inf, vtrunc=Inf, trav=true)` from [HierarchicalUtils.jl](https://github.com/Sheemon7/HierarchicalUtils.jl) which prints the whole schema, together with identifiers of individual nodes:

```julia
julia> printtree(sch; htrunc=Inf, vtrunc=Inf, trav=true)
[Dict] (updated = 3) [""]
  ├── a: [MultiEntry] (updated = 3) ["E"]
  │        ├── 1: [Scalar - String], 2 unique values, updated = 2 ["I"]
  │        └── 2: [List] (updated = 1) ["M"]
  │                 └── [Scalar - String], 2 unique values, updated = 2 ["O"]
  └── b: [Dict] (updated = 3) ["U"]
           ├── c: [Scalar - Int64], 2 unique values, updated = 3 ["Y"]
           └── d: [MultiEntry] (updated = 3) ["c"]
                    ├── 1: [Scalar - Int64], 2 unique values, updated = 2 ["d"]
                    └── 2: [List] (updated = 1) ["e"]
                             └── [Scalar - Int64], 3 unique values, updated = 3 ["eU"]
```

Strings at the end of each row can be used as a key to access individual elements of the schema.
For more about [HierarchicalUtils.jl](https://github.com/Sheemon7/HierarchicalUtils.jl) check their docs or [section about HierarchicalUtils.jl in Mill.jl documentation](https://pevnak.github.io/Mill.jl/dev/tools/hierarchical/)

Here, we see that we have 2 `MultiEntry`, thus 2 type instabilities in our jsons.
The first `MultiEntry` (key `"E"`) has 2 children: `Entry` and `ArrayEntry`.

The `sch["E"].updated` is 3, because value under key `a` in json has been observed 3 times.
The `sch["I"].updated` is 2, because string value was seen 2 times under `a`.
As expected, we can see
```julia
julia> sch["I"].counts
Dict{String,Int64} with 2 entries:
  "Hello" => 1
  "World" => 1
```

and in the ArrayEntry we can see `sch["M"].updated` is 1, because array has been observed once in key `a`.
The freqency of lengths is following:
```julia
julia> sch["M"].l
Dict{Int64,Int64} with 1 entry:
  2 => 1
```

because we have observed one array of length 2.
`sch["M"].items` is `Entry`.

The Entry (can be accessed by `sch["M"].items` or by `sch["O"]`) has fields with following values:

`sch["O"].updated` is 2, because we have observed 2 elements in array under key `a`.  

`counts` is
```julia
julia> sch["O"].counts
Dict{String,Int64} with 2 entries:
"Hi"    => 1
"Julia" => 1
```
which corresponds to individual elements of an array we have observed.


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
