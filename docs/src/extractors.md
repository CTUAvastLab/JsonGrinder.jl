# Creating extractor

Extractor is responsible for converting json to Mill structures. The main design idea is that the extractor for a whole json is created by composing (sub-)extractors while reflecting the JSON structure. This composability is achieved by the **commitment** of each extractor returning a subtype of `Mill.AbstractDataNode`. Extractor can be any function, but to ensure a composability, it is should be a subtype of `AbstractExtractor`, which means all of them being implemented as functors (also because they contain parameters). 

Extractor can be almost automatically created by calling a function `suggestextractor` on a schema. While extractors for `Dict` and `Arrays` are relatively straightforward, extractors for leafs are tricky, as one needs to decide, if the leaf should be represented as a  `Float` and `String` are represented as `Categorical` variables. Calling `suggestextractor(schema)` uses a simple heuristic (described below), it is therefore highly recommended to check the proposed extractor manually, if it makes sense. A typical error, especially if schema is created from a small number of samples, is that some variable is treated as a categorical, while it should be `String` / `Float`.

# Default heuristics
```
JsonGrinder.suggestextractor(schema, settings::NamedTuple)

```
allows to pass your own heuristic and rules for handling scalars. Extractors for `Dict` and `Array`s are not configurable, as we believe there is not much to do, but there are some *magic* described below.

## Scalars
By default,
```
settings = (scalar_extractors = default_scalar_extractor())
```

`scalar_extractors` is a list of tuples, where the first is a condition and the second is a function creating the extractor in case of a true. The default heuristic is following and 
you can adjust according to your liking. 
```
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
{"a.dll" = ["f", "g", "h"],
 "b.dll" = ["a", "b", "c"]}
{"c.dll" = ["x", "y", "z"]}
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

