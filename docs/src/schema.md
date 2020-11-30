# Schema

Unlike XML or ProtoBuffer, JSON file format do not adhere to any schema. `JsonGrinder.jl` assumes that although not explicitly defined, there exists a schema which defines the structure of files. Schema is essential for creation of extractors, as to know, how to convert values, knowing what values the key can hold is helpful. Therefore `schema` is here to collect statistics of occurrences of individual keys and their values in a set of provided jsons. Just call 

`JsonGrinder.schema` collect statistics from a set of JSONs in `DictEntry`, `ArrayEntry`,  and `Entry` keeping the structure of JSONs. For the case of JSONs with non-stable schema, there is a `MultiEntry,` but we strongly recommend to preprocess JSONs to be stable.

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


```julia
mutable struct ArrayEntry <: JSONEntry
	items
	l::Dict{Int,Int}
	updated::Int
end
```
`ArrayEntry` keeps information about arrays (e.g. `"a" = [1,2,3,4]`). Statistics about individual items of the array are deffered to `item`, which can be `<:JSONEntry`. `l` stores keeps histogram of lengts of arrays, and `updated` is keep number of times this key has been observed.


```julia
mutable struct DictEntry <: JSONEntry
	childs::Dict{Symbol, Any}
	updated::Int
end
```
deferes all statistics about its children to them, and the only statistic is again a counter `updated,` about observation times.

```julia
mutable struct MultiEntry <: JSONEntry
	childs::Vector{JSONEntry}
	updated::Int
end
```
is a failsave for cases, where the schema is not stable. For example in following two JSONs
```
{"a" = "Hello"}
{"a" = ["Hello"," world"]}
```
the type of a value of a key `"a"` is `String`, whereas in the second it is `"Vector"`. The JsonGrinder will deal with this by first creating an `Entry`, since the value is scalar, and upon encountering the second JSON, it will replace `Entry` with `MultiEntry` having `Entry` and `ArrayEntry` as childs (this is the reason why entries are declared mutable). *While JsonGrinder can deal with non-stable jsons, it is strongly discouraged as it might have negative effect on the performance.*

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
prune_json
```

```@docs 
updatemaxkeys!
```

```@docs 
updatemaxlen!
```
