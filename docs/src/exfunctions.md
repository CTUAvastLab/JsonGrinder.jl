# Extractor functions

Below, we first describe extractors of values (i.e. leaves of JSON tree), then proceed to description of extractors of `Array` and `Dict`, and finish with some specials.

Extractors of scalar values are arguably the most important, but also fortunately the most understood ones. They control, how values are converted to a `Vector` (or generally tensor) for the neural networks. For example they control, if number should be represented as a number, or as one-hot encoded categorical variable. Similarly, they control how `String` should be treated, although we admit to natively support only n-grams.

<!-- this is relevant from JsonGrinder 2.2.0 -->
<!-- Because `JsonGrinder` supports working with missing values, each leaf extractor has `uniontypes` field which determines if it can return missing values or not, and based on this field, extractor returns appropriate data type. -->
<!-- By default, `uniontypes` is false but we advice to set it during extractor construction according to your data. -->

Because mapping from JSON (or different hierarchical structure) to `Mill` structures can be non-trivial, extractors have keyword argument `store_input`, which, if `true`, causes input data to be stored as metadata of respective `Mill` structure. By default, it's false, because it can cause type-instability in case of irregular input data and thus suffer from performance loss. The `store_input` argument is propagated to leaves and is used to store primarily leaf values.

Recall

```@setup 1
using Mill, JSON
```

## Numbers
<!-- ```julia
struct ExtractScalar{T} <: AbstractExtractor
	c::T
	s::T
	uniontypes::Bool
end
``` -->
```julia
struct ExtractScalar{T} <: AbstractExtractor
	c::T
	s::T
end
```
Extracts a numerical value, centered by subtracting `c` and scaled by multiplying by `s`.
Strings are converted to numbers. The extractor returns `ArrayNode{Matrix{T}}` with a single row if `uniontypes` if `false`, and `ArrayNode{Matrix{Union{Missing, T}}}` with a single row if `uniontypes` if `true`.
```@example 1
e = ExtractScalar(Float32, 0.5, 4.0)
e("1").data
```

`missing` value is extracted as a missing value, as it is automatically handled downstream by `Mill`.
```@example 1
e(missing)
```

the `e("1")` is equivalent to `e("1", store_input=false)`. To see input data in metadata of `ArrayNode`, we can run

```@example 1
e("1", store_input=true).metadata
```

data remain unchanged

```@example 1
e("1", store_input=true).data
```

by default, metadata contains `nothing`

```@example 1
e("1").metadata
```

## Strings
```julia
struct ExtractString{T} <: AbstractExtractor
	n::Int
	b::Int
	m::Int
end
```
Represents `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

```@example 1
e = ExtractString()
e("Hello")
```

`missing` value is extracted as a missing value, as it is automatically handled downstream by `Mill`.
```@example 1
e(missing)
```

Storing input works in the same manner as for `ExtractScalar`, see
```@example 1
e("Hello", store_input=true).metadata
```

it works the same also with missing values
```@example 1
e(missing, store_input=true).metadata
```

## Categorical
```julia
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::Int
end
```
Converts a single item to a one-hot encoded vector. For a safety, there is always an
extra item reserved for an unknown value.
```@example 1
e = ExtractCategorical(["A","B","C"])
e(["A","B","C","D"]).data
```

`missing` value is extracted as a missing value, as it is automatically handled downstream by `Mill`.
```@example 1
e(missing)
```

Storing input in this case looks as follows
```@example 1
e(["A","B","C","D"], store_input=true).metadata
```

## Array (Lists / Sets)
```julia
struct ExtractArray{T}
	item::T
end
```
Convert array of values to a `Mill.BagNode` with items converted by `item`. The entire array is assumed to be a single bag.

```@example 1
sc = ExtractArray(ExtractCategorical(["A","B","C"]))
sc(["A","B","C","D"])
```

Empty arrays are represented as an empty bag.
```@example 1
sc([]).bags
```
The data of empty bag can be either `missing` or a empty sample, which is more convenient as it makes all samples of the same type, which is nicer to AD. This behavior is controlled by `Mill.emptyismissing`. The extractor of a `BagNode` can signal to child extractors to extract a sample with zero observations using a special singleton `JsonGrinder.extractempty`. For example

```@example 1
Mill.emptyismissing!(true)
sc([]).data
```
```@example 1
Mill.emptyismissing!(false)
sc([]).data
```

Storing input is delegated to leaf extractors, so metadata of bag itself are empty

```@example 1
sc(["A","B","C","D"], store_input=true).metadata
```

but metadata of underlying `ArrayNode` contain inputs.

```@example 1
sc(["A","B","C","D"], store_input=true).data.metadata
```

In case of empty arrays, input is stored in metadata of `BagNode` itself, because there might not be any underlying `ArrayNode`.

```@example 1
sc([], store_input=true).metadata
```


## Dict
```julia
struct ExtractDict
	dict::Dict{Symbol,Any}
end

```
Extracts all items in `dict` and return them as a ProductNode. Key in dict corresponds to keys in JSON.
```@example 1
ex = ExtractDict(Dict(:a => ExtractScalar(),
	:b => ExtractString(),
	:c => ExtractCategorical(["A","B"]),
	:d => ExtractArray(ExtractString())))
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]))
```

Missing keys are replaced by `missing` and handled by child extractors.
```@example 1
ex(Dict(:a => "1",
	:c => "A"))
```


Describe extractempty to signal that we need to extract empty variable

# Specials

## ExtractKeyAsField
Some JSONs we have encountered uses structure to hold an array for named lists (or other types). Having computer security background a prototypical example is storing a list of DLLs with a corresponding list of imported function in a single structure. For example a JSON
```json
{ "foo.dll" : ["print","write", "open","close"],
  "bar.dll" : ["send", "recv"]
}
```
should be better written as
```json
[{"key": "foo.dll",
  "item": ["print","write", "open","close"]},
  {"key": "bar.dll",
  "item": ["send", "recv"]}
]
```
JsonGrinder tries to detect these cases, as they are typically manifested by `Dicts` with excessively large number of keys in a schema. The detection logic of this case in `suggestextractor(e::DictEntry)` is simple, if the number of keys is greater than `settings.key_as_field = 500`.

The extractor itself is simple as well. For the case above, it would look like
```@example 1
s = JSON.parse("{ \"foo.dll\" : [\"print\",\"write\", \"open\",\"close\"],
  \"bar.dll\" : [\"send\", \"recv\"]
}")
ex = ExtractKeyAsField(ExtractString(),ExtractArray(ExtractString()))
ex(s)
```

## MultipleRepresentation
Provides a dual representation for a single key. For example imagine that are extracting strings with some very freuquently occuring values and a lots of clutter, which might be important and you do not know about it. `MultipleRepresentation(extractors::Tuple)` contains a `Tuple` or `NamedTuple` of extractors and apply them to a single sub-tree in a json. The corresponding `Mill` structure will contain `ProductNode` of both representation.

 For example `String` with *Categorical* and *NGram* representation will look like.
```@example 1
ex = MultipleRepresentation((c = ExtractCategorical(["Hello","world"]), s = ExtractString()))
reduce(catobs,ex.(["Hello","world","from","Prague"]))
```

`MultipleRepresentation` together with handling of `missing` values enables JsonGrinder to deal with JSONs with non-stable schema.


#explain, how to customize conversion of schema to extractors extractors to
