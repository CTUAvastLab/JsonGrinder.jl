# Extractor functions

Below, we first describe extractors of values (i.e. lists of JSON tree), then proceed to description of extractors of `Array` and `Dict`, and finish with some specials.

Extractors of scalar values are arguably the most important, but also fortunatelly the most undersood ones. They control, how values are converted to a `Vector` (or generally tensor) for the neural networks. For example they control, if number should be represented as a number, or as one-hot encoded categorical variable. Similarly, it constrols how `String` should be treated, although we admit to natively support on ngrams. Recall 

## Numbers
```julia
struct ExtractScalar{T}
	c::T
	s::T
end
```
Extract a numerical value, centred by subtracting `c` and scaled by multiplying by `s`. 
Strings are converted to numbers. The extractor returnes `ArrayNode{Matrix{T}}` 
with a single row. 
```@example 1
using JsonGrinder, Mill, JSON #hide
e = ExtractScalar(Float32, 0.5, 4.0)
e("1").data
```

`missing` value is extracted as a missing value, as it is automatically handled downstream by `Mill`.
```@example 1
e(missing)
```

## Strings
```julia
struct ExtractString{T}
	datatype::Type{T}
	n::Int
	b::Int
	m::Int
end
```
Represent `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.


```@example 1
e = ExtractString()
e("Hello")
```

`missing` value is extracted as a missing value, as it is automatically handled downstream by `Mill`.
```@example 1
e(missing)
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
[{"key" = "foo.dll",
  "item" = ["print","write", "open","close"]},
  {"key = "bar.dll",
  "item" = ["send", "recv"]}
]
```
JsonGrinder tries to detect these cases, as they are typically manisfested by `Dicts` with excessively large number of keys in a schema. The detection logic of this case in `suggestextractor(e::DictEntry)` is simple, if the number of keys is greater than `settings.key_as_field = 500`.

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

## ExtractOneHot(ks, k, v) 
Some JSONs we have encountered encode histograms in a an array containing structures with a name of the bin and its count. In the example below, the name of the bin (further called `key`) and corresponding count in the bin is called `value`. In example below, `key` is equal to `name` and the `value` is equal to `count`.
```
[{\"name\": \"a\", \"count\" : 1},
{\"name\": \"b\", \"count\" : 2}]
```
This histogram is extracted as a `BagNode` with a wrapped `SparseMatrix` containing the key-value pairs, each pair in a separate We represent them as SparseMatrices with one line per item for example as
```@example 1
vs = JSON.parse("[{\"name\": \"a\", \"count\" : 1}, {\"name\": \"b\", \"count\" : 2}]")
e = ExtractOneHot(["a","b"], "name", "count");
e(vs).data
```
Notice that the matrix has an extra dimension  reserved for unknown keys.
The array is handled as a bag. For example for the above example
```@example 1
e(vs)
```

The extractor itself is a structure defined as
```
struct ExtractOneHot{K,I,V} <: AbstractExtractor
	k::K
	v::V
	key2id::Dict{I,Int}
	n::Int
end
```
where `k` / `v` is the name of an entry indetifying key / value, and `key2id` converts the value of the key to the the index in the sparse array. A constructor `ExtractOneHot(ks, k, v)` assumes `k` and `v` as above and `ks` being list of key values. 






#explain, how to customize conversion of schema to extractors extractors to 