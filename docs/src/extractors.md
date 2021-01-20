# Creating extractor

Extractor is responsible for converting json to Mill structures. The main design idea is that the extractor for a whole json is created by composing (sub-)extractors while reflecting the JSON structure. This composability is achieved by the **commitment** of each extractor returning a subtype of `Mill.AbstractDataNode`. Extractor can be any function, but to ensure a composability, it is should be a subtype of `AbstractExtractor`, which means all of them are implemented as functors (also because they contain parameters).

# Manual creation of extractors
The simplest way to create a custom extractor is the compose it from provided extractor functions. Imagine for example json file as follows.
```json
{"name": "Karl",
 "siblings": ["Gertruda", "Heike", "Fritz"],
 "hobby": ["running", "pingpong"],
 "age": 21,
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

Applying the extractor `ex` on the above json yield the corresponding `Mill` structure.

```@example 1
s = JSON.parse("{\"name\" : \"Karl\",
 \"siblings\" : [\"Gertruda\", \"Heike\", \"Fritz\"],
 \"hobby\" : [\"running\", \"pingpong\"],
 \"age\" : 21
}")
ex(s)
```


The list of composable extractor function that we have found handy during our experiments are listed in *Extractor functions* section of the doc.

# Semi-automatic creation of extractors
Manually creating extractors is boring and error-prone process. Function `suggestextractor(schema)` tries to simplify this, since creation of most of the extractors is straightforward, once the the schema is known. This is especially true for `Dict` and `Arrays`, while extractors for leafs can be tricky, as one needs to decide, if the leaf should be represented as a  `Float` and `String` are represented as `Categorical` variables. `suggestextractor(schema)` uses a simple heuristic (described below) choosing reasonable extractors, but it can make errors. It is therefore highly recommended to check the proposed extractor manually, if it makes sense. A typical error, especially if schema is created from a small number of samples, is that some variable is treated as a categorical, while it should be `String` / `Float`.

```julia
JsonGrinder.suggestextractor(schema, settings::NamedTuple)
```

allows to pass your own heuristic and rules for handling scalars. By default,
`settings = (scalar_extractors = default_scalar_extractor()).`
Extractors for `Dict` and `Array`s are not configurable, as we do not feel the pressure to so, as there does not seems to be much to do, but of course there is some *dark magic* described below.

## Scalars

`scalar_extractors` is a list of tuples, where the first is a condition and the second is a function creating the extractor in case of a true. The default heuristic is following and
you can adjust according to your liking.
```julia
function default_scalar_extractor()
	[
	# all floatable keys are also intable AFAIK
	(e -> length(keys(e)) <= 100 && is_floatable(e),
		e -> ExtractCategorical(keys(e))),
	# it's important that condition here would be lower than maxkeys
	(e -> (keys_len = length(keys(e)); keys_len / e.updated < 0.1 && keys_len < 10000),
		e -> ExtractCategorical(keys(e))),
	(e -> is_intable(e),
		e -> extractscalar(Int32, e)),
	(e -> is_floatable(e),
	 	e -> extractscalar(FloatType, e)),
	(e -> true,
		e -> extractscalar(unify_types(e), e)),]
end
```

## Arrays
Extractor suggested for `ArrayEntry` is most of the time `ExtractArray` converting `Array`s to `Mill.BagNode`s. The exception is the case, when vectors are of the same length and their items are numbers. In this case, the suggestextractor returns `ExtractVector`, which treats convert the array to a `Mill.ArrayNode`, as we believe the array to represent a feature vector.

## Dict
Extractor suggested for `DictEntry` is most of the time `ExtractDict` converting `Dict`s to `ProductNode`s. Again, there is an excetion. Sometimes, people use `Dict`s with names of keys being values.
For example consider following two jsons
```json
{"a.dll": ["f", "g", "h"],
 "b.dll": ["a", "b", "c"]}
{"c.dll": ["x", "y", "z"]}
```
in the case, keys `["a.dll","b.dll","c.dll"]` are actually values (names of libraries), and arrays are values as well. The dictionary therefore contain an array. If this case is detected, it is suggested to use `ExtractKeyAsField`, which interprests the above JSON as
```
[{key = "a.dll",
  field = ["f", "g", "h"]},
 {key = "b.dll",
 field = ["a", "b", "c"]}
]
[{key = "c.dll",
field = ["x", "y", "z"]}]
```
`ExtractKeyAsField` extractor convert it to `Mill.BagNode(Mill.ProductNode((key=..., field=...)))`
