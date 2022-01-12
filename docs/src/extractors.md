# Creating an Extractor

Extractor is responsible for converting json to `Mill` structures. 
The main design idea is that the extractor for a whole json is created by composing (sub-)extractors while reflecting the JSON structure. 
This composability is achieved by the **commitment** of each extractor returning a subtype of `Mill.AbstractDataNode`. 
Extractor can be any function, but to ensure a composability, it is should be a subtype of `AbstractExtractor`, 
which means all of them are implemented as functors (also because they contain parameters).

# Manual creation of extractors
The simplest way to create a custom extractor is the compose it from provided extractor functions. Imagine for example json file as follows.
```json
{"name": "Karl",
 "siblings": ["Gertruda", "Heike", "Fritz"],
 "hobby": ["running", "pingpong"],
 "age": 21
}
```

A corresponding extractor might look like

```@example 1
using JsonGrinder, Mill, JSON #hide
ex = ExtractDict(Dict(
	:name => ExtractString(),
	:siblings => ExtractArray(ExtractString()),
	:hobby => ExtractArray(ExtractCategorical(["running", "swimming","yoga"])),
	:age => ExtractScalar(),
))
```
Notice, how the composability of extractors simplifies the desing and allow to reflect the same feature of JSON documents.

Applying the extractor `ex` on the above json yields the corresponding `Mill` structure.

```@example 1
s = JSON.parse("{\"name\" : \"Karl\",
 \"siblings\" : [\"Gertruda\", \"Heike\", \"Fritz\"],
 \"hobby\" : [\"running\", \"pingpong\"],
 \"age\" : 21
}")
ex(s)
```

The list of all extractors that we have found handy during our experiments and are part of `JsonGrinder` can be found in [Extractors overview](@ref).

# Semi-automatic creation of extractors
Manually creating extractors is boring and error-prone process. Function `suggestextractor(schema)` tries to simplify this, 
since creation of most of the extractors is straightforward, once the schema is known.

This is especially true for `Dict` and `Arrays`, while extractors for leaves can be tricky, as one needs to decide, 
if the leaf should be represented as a `Scalar` and `String` or as `Categorical` variable.

The sample diagram below shows the various selections of variable representations. 
In the example, there are 42 different *TCP destination port* values, while the *TCP source port* has more variability in the data. 
Therefore, a `categorical variable` is selected for the *destination port*, while the *source port* is represented as `Float32`.
```
KeyAsField
  ├── String
  └── Array of
        └── Dict
              ├─── ip: Dict
              │          ├── dst: Categorical d = 4416
              │          └── src: Categorical d = 4
              ├── tcp: Dict
              │          ├────── dstport: Categorical d = 42
              │          ├────── srcport: Float32
              │          └── window_size: Float32
              └── udp: Dict
                         ├─────── udp.dstport: Float32
                         ├──────── udp.length: Float32
                         ├─────── udp.srcport: Float32
```

`suggestextractor(schema, settings)` uses a simple heuristic (described below) for choosing reasonable extractors, but it can make errors. 
It is therefore **highly recommended** to check the proposed extractor manually, if it makes sense. 
A typical error, especially if schema is created from a small number of samples, is that some variable is treated as a `Categorical`, 
while it should be `String` / `Scalar`.

Extractor for `Dict` can be configured to use either `ExtractDict` or `ExtractKeyAsField` based on properties number of keys in schema.

Extractor for `Array` is not configurable, as we do not feel the pressure to so, as there does not seems to be much to do.


```julia
JsonGrinder.suggestextractor(schema, settings = NamedTuple())
```
allows to pass following parameters inside the `settings` argument
- `scalar_extractors`
- `key_as_field`
- `mincountkey`

`scalar_extractors` allows to pass your own heuristic and rules for handling scalars.

By default, it's `settings = (; scalar_extractors = default_scalar_extractor())`.

`key_as_field` is an `Int` parameter which configures how `Dict`s are extracted. 
If number of unique keys in dict is >= `key_as_field`, [ExtractKeyAsField](@ref) is used, otherwise [ExtractDict](@ref exfuctions_ExtractDict) is used.

By default, it's `settings = (; key_as_field = 500)`.

`mincountkey` is an `Int` parameter which allows you to skip sparse keys in `Dict` to avoid creation of unnecessarily large model.
`mincountkey` contains minimum number of observations of the key in schema to be included in extractor. 
All keys, whose `updated` field in schema for specific key is > `mincountkey` are included in resulting `ExtractDict`.
This setting applies only to `Dict`s which are not considered to be "key as field". 
If a certain `Dict` is considered to be extracted by `ExtractKeyAsField`, `mincountkey` does not apply to it.

By default, it's `settings = (; mincountkey = 0)`, thus no keys are omitted by default.

## Scalars

`scalar_extractors` is a list of tuples, where the first is a condition and the second is a function creating the extractor in case of a true. 
The default heuristic is following and you can adjust according to your liking.

```julia
function default_scalar_extractor()
	[
	(e -> length(keys(e)) <= 100 && is_numeric_or_numeric_string(e),
		(e, uniontypes) -> ExtractCategorical(keys(e), uniontypes)),
	(e -> is_intable(e),
		(e, uniontypes) -> extractscalar(Int32, e, uniontypes)),
	(e -> is_floatable(e),
	 	(e, uniontypes) -> extractscalar(FloatType, e, uniontypes)),
	# it's important that condition here would be lower than maxkeys
	(e -> (keys_len = length(keys(e)); keys_len / e.updated < 0.1 && keys_len < 10000 && !is_numeric_or_numeric_string(e)),
		(e, uniontypes) -> ExtractCategorical(keys(e), uniontypes)),
	(e -> true,
		(e, uniontypes) -> extractscalar(unify_types(e), e, uniontypes)),]
end
```

Note that order matters here, as the extractors are suggested using following logic
```julia
for (c, ex) in get(settings, :scalar_extractors, default_scalar_extractor())
	c(e) && return ex(e)
end
```

## Arrays
Extractor suggested for `ArrayEntry` is most of the time `ExtractArray` converting `Array`s to `Mill.BagNode`s. 
The exception is the case, when vectors are of the same length and their items are numbers. In this case, 
the `suggestextractor` returns `ExtractVector`, which treats convert the array to a `Mill.ArrayNode`, as we believe the array to represent a feature vector.

## Dict

Extractor suggested for `DictEntry` is most of the time `ExtractDict` converting `Dict`s to `ProductNode`s. 
As mentioned above, there is an excetion. Sometimes, people use `Dict`s with names of keys being values.
For example consider following two jsons
```json
{"a.dll": ["f", "g", "h"],
 "b.dll": ["a", "b", "c"]}
{"c.dll": ["x", "y", "z"]}
```
in the case, keys `["a.dll","b.dll","c.dll"]` are actually values (names of libraries), and arrays are values as well. 
The dictionary therefore contain an array. If this case is detected, it is suggested to use `ExtractKeyAsField`, which interprets the above JSON as
```json
[{"key": "a.dll",
  "field": ["f", "g", "h"]},
 {"key": "b.dll",
 "field": ["a", "b", "c"]}
]
[{"key": "c.dll",
"field": ["x", "y", "z"]}]
```

To demonstrate difference between them, let's compare resulting `Mill` structures.
```@repl 1
s1 = JSON.parse("{\"a.dll\": [\"f\", \"g\", \"h\"],
 \"b.dll\": [\"a\", \"b\", \"c\"]}")
s2 = JSON.parse("{\"c.dll\": [\"x\", \"y\", \"z\"]}")
ex_dict = ExtractDict(Dict(
	Symbol("a.dll") => ExtractArray(ExtractString()),
	Symbol("b.dll") => ExtractArray(ExtractString()),
	Symbol("c.dll") => ExtractArray(ExtractString()),
))
ex_key_as_field = ExtractKeyAsField(
	ExtractString(), ExtractArray(ExtractString()
))
ex_dict(s1)
ex_key_as_field(s1)
ex_dict(s2)
ex_key_as_field(s2)
```

As we can see `ExtractKeyAsField` extracts data to more sensible structures in this case.

## Modifying extractor

### Passing different scalar_extractors

Let's demonstrate how can we set extraction of all strings to be `MultiRepresentation` of `String` and `Categorical`, 
where `Categorical` will have 20 most frequent values. In general, there are 2 approaches:
 - prepending your own extractors to `default_scalar_extractor()`
 - providing your own function independent on `default_scalar_extractor()`
The first case may look as follows:
```julia
# we import necessary functions
using JsonGrinder: is_intable, is_floatable, unify_types, extractscalar
# define a helper function
top_n_keys(e::Entry, n::Int) = map(x->x[1], sort(e.counts |> collect, by=x->x[2], rev=true)[begin:min(n, end)])
# we call the default extractor inside our
function string_multi_representation_scalar_extractor()
	vcat([
	(e -> unify_types(sch[:paper_id]) <: String,
		e -> MultipleRepresentation((
			ExtractCategorical(top_n_keys(e, 20)),
			extractscalar(unify_types(e), e)
		))
	], JsonGrinder.default_scalar_extractor()))
end
# call the suggestextractor with out extractors
suggestextractor(sch, (; scalar_extractors = string_multi_representation_scalar_extractor()))
```

The second case may look as follows:
Let's take contents `default_scalar_extractor()` function and modify it
```julia
# we import necessary functions
using JsonGrinder: is_intable, is_floatable, unify_types, extractscalar
# define a helper function
top_n_keys(e::Entry, n::Int) = map(x->x[1], sort(e.counts |> collect, by=x->x[2], rev=true)[begin:min(n, end)])
function string_multi_representation_scalar_extractor()
	[
	(e -> length(keys(e)) <= 100 && (is_intable(e) || is_floatable(e)),
		e -> ExtractCategorical(keys(e))),
	(e -> is_intable(e),
		e -> extractscalar(Int32, e)),
	(e -> is_floatable(e),
	 	e -> extractscalar(FloatType, e)),
	# it's important that condition here would be lower than maxkeys
	(e -> (keys_len = length(keys(e)); keys_len / e.updated < 0.1 && keys_len < 10000 && !(is_intable(e) || is_floatable(e))),
		e -> ExtractCategorical(keys(e))),
	(e -> true,
		e -> MultipleRepresentation((
			ExtractCategorical(e, 20),
			extractscalar(unify_types(e), e)
			)
		)),]
end
# call the suggestextractor with out extractors
suggestextractor(sch, (; scalar_extractors = string_multi_representation_scalar_extractor()))
```

Note that in the first case, the condition for new extractor is evaluated first, but in the latter case, it's the latest condition, 
so it's used only when the previous ones are not met.

### Manual modifications of extractor
Because the extractor can be quite big, by default the `Base.show` shows only structure to depth of 3 and 20 children for each element.

The full extractor can by seen by `HierarchicalUtils.printtree(extractor)`.
Usually edge-cases and complex cases are seen only on large schemas and extractors, which don't suit the documentation format. 
Thus the examination of schema and extractor, and manual modifications are in dedicated example 
[examples/schema_examination.jl](https://github.com/CTUAvastLab/JsonGrinder.jl/blob/master/examples/schema_examination.jl)
which creates schema and extractor based on data in [examples/documents](https://github.com/CTUAvastLab/JsonGrinder.jl/blob/master/examples/documents). 
We advice to check it out and try to run it by yourself.
