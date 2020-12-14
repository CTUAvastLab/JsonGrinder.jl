# Extractors

Extractors are responsible for converting json elements to Mill structures. The main idea behind them is to compose them in a structure reflecting the structure of JSON, which means that parents do not need to know, how childs are represented, as they know that the extracted data will be of subtype of `Mill.AbstractDataNode`. This means that the output of any extractor has to be a subtype of `Mill.AbstractDataNode`, which ensures composability. Note that representation of missing data is handled by `Mill.jl`.

Extractor can be any function which takes a JSON (or its part) as an input, and return a valid MILL datanode. Most extractors are implemented as functors, since most of them contain parameters. 

Extractors can be created automatically by calling a function `suggestextractor` on a schema, which implements our heuristics how to convert leaf variables to tensors. It is highly recommended to check the proposed extractor manually, if it makes sense. An error, especially if schema is created from a small number of samples, is that `Float` and `String` are represented as `Categorical` variables.

Below, we first describe extractors of values (i.e. lists of JSON tree), then proceed to description of extractors of `Array` and `Dict`, and finish with some specials.

## Scalar values
Extractors of scalar values are arguably the most important, but also fortunatelly the most undersood ones. They control, how values are converted to a `Vector` (or generally tensor) for the neural networks. For example they control, if number should be represented as a number, or as one-hot encoded categorical variable. Similarly, it constrols how `String` should be treated, although we admit to natively support on ngrams. Recall 

### Numbers
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
using JsonGrinder, Mill #hide
e = ExtractScalar(Float32, 0.5, 4.0)
e("1").data
```

`missing` value is extracted as a missing value, as it is automatically handled downstream by `Mill`.
```@example 1
e(missing)
```

### Strings
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

### Categorical
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

## Array
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

## Specials

### ExtractKeyAsField
```julia
struct ExtractKeyAsField{S,V} <: AbstractExtractor
	key::S
	item::V
end
```
Extracts all items in `vec` and in `other` and return them as a ProductNode.

### MultipleRepresentation 
```julia
MultipleRepresentation(extractors::Tuple)
```
create a `ProductNode` where each item is the json part processed by all extractors in the order



### ExtractOneHot(ks, k, v) 

Many jsons encode a histograms as
```
[{\"name\": \"a\", \"count\" : 1},
{\"name\": \"b\", \"count\" : 2}]
```
We represent them as SparseMatrices with one line per item for example as
```@example 1
e = ExtractOneHot(["a","b"], "name", "count");
e(vs).data
```
and handle the array externally as a bag. The matrix has an extra dimension  reserved for unknown keys.
The extractor is defined as
```
struct ExtractOneHot{K,I,V} <: AbstractExtractor
	k::K
	v::V
	key2id::Dict{I,Int}
	n::Int
end
```
where `k` / `v` is the name of an entry indetifying key / value, and `key2id` converts the value of the key to the the numeric index. A constructor `ExtractOneHot(ks, k, v)` assumes `k` and `v` as above and `ks` being list of key values. 






#explain, how to customize conversion of schema to extractors extractors to 