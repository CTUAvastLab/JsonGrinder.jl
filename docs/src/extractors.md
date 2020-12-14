# Extractors

Extractors are responsible for converting json elements to Mill structures. The main idea behind them is to compose them in a structure reflecting the structure of JSON, which means that parents do not need to know, how childs are represented, as they know that the extracted data will be of subtype of `Mill.AbstractDataNode`. This means that the output of any extractor has to be a subtype of `Mill.AbstractDataNode`, which ensures composability. Note that representation of missing data is handled by `Mill.jl`.

Extractor can be any function which takes a JSON (or its part) as an input, and return a valid MILL datanode. Most extractors are implemented as functors, since most of them contain parameters. 

Extractors can be created automatically by `suggestextractor`, which takes a schema and based on the statistics it suggests an extractor. It is highly recommended to check the proposed extractor manually, if the representation makes sense (for example if a `Float` / `String` is not by accident extracted as a `Categorical`).

We will first describe extractors of values (i.e. lists of JSON tree), then proceed to description of extractors of `Array` and `Dict`, and finish with some specials.

## Scalar values
Extractors of scalar values are probably the most important, and fortunatelly the most undersood ones. The control, how the values are represented in a `Vector` form for the neural networks. For example, should the number be represented as a number, or as one-hot encoded categorical variable. And how `String` should be treated? In the explanation below, keep in mind that it is the `Extractor`s controlling how the variable will be represented. 

### Numbers
```julia
struct ExtractScalar{T}
	c::T
	s::T
end
```
converts numerical values to type `T`, subtract `c` and multiplies it by `s`. Strings are converted to numbers.

`ExtractScalar(e::Entry)` initializes a scalar extractor such that the extracted values are in interval `[0,1]`. Strings containing exclusively numerical values are treated as numbers.
```@example 1
using JsonGrinder #hide
e = ExtractScalar(Float32, 0.5, 4.0)
e(1)
e(1).data
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
Represent `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`. `ExtractString(e::Entry)` / `ExtractScalar(e::Entry)` initializes the extractor with `n = 3, b = 256, m = 2053`.

```@example 1
e = ExtractString(String)
e("Hello")
```

### Categorical
```julia
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::Int
end
```
Converts a single item to a one-hot encoded vector. There is always alocated an extra element for a unknown value. The constructor `ExtractCategorical(s::Entry)` take all keys of `e.counts` as values in the categorical arrays.

```@example 1
e = ExtractCategorical(["A","B","C"])
e(["A","B","C","D"]).data
```

## Extract Array
Describe extractempty to signal that we need to extract empty variable



## Specials

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