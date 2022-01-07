# Extractors overview

Below, we first describe extractors of values (i.e. leaves of JSON tree), 
then proceed to description of extractors of `Array` and `Dict`, and finish with some specials.

Extractors of scalar values are arguably the most important, but also fortunately the most understood ones. 
They control, how values are converted to a `Vector` (or generally tensor) for the neural networks. 
For example, they control, if number should be represented as a number, or as one-hot encoded categorical variable. 
Similarly, they control how `String` should be treated, although we admit to natively support only n-grams.

Because mapping from JSON (or different hierarchical structure) to `Mill` structures can be non-trivial, 
extractors have keyword argument `store_input`, 
which, if `true`, causes input data to be stored as metadata of respective `Mill` structure. By default, it's false, 
because it can cause type-instability in case of irregular input data and thus suffer from performance loss. 
The `store_input` argument is propagated to leaves and is used to store primarily leaf values.

Because `JsonGrinder` supports working with missing values, each leaf extractor has `uniontypes` field which determines 
if it can return missing values or not, and based on this field, extractor returns appropriate data type.
By default, `uniontypes` is true, so it supports missing values of the shelf, 
but we advise to set it during extractor construction according to your data because it may create unnecessarily many parameters otherwise. 
[`suggestextractor`](@ref) takes into account where missing values can be observed and where not based on statistics 
in schema and provides sensible default extractor.

Recall

```@setup 1
using JsonGrinder, Mill, JSON, StatsBase
```

## Numbers

```julia
struct ExtractScalar{T} <: AbstractExtractor
	c::T
	s::T
	uniontypes::Bool
end
```
Extracts a numerical value, centered by subtracting `c` and scaled by multiplying by `s`.
Strings are converted to numbers. The extractor returns `ArrayNode{Matrix{T}}` with a single row if `uniontypes` if `false`, 
and `ArrayNode{Matrix{Union{Missing, T}}}` with a single row if `uniontypes` if `true`.
```@example 1
e = ExtractScalar(Float32, 0.5, 4.0, true)
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

by default, metadata contains `nothing`.

And if `uniontypes` is false, it looks as follows

```@repl 1
e = ExtractScalar(Float32, 0.5, 4.0, true)
e("1").data
e("1", store_input_true=true).data
e("1", store_input_true=true).metadata
e(missing)
```

## Strings
```julia
struct ExtractString <: AbstractExtractor
	n::Int
	b::Int
	m::Int
	uniontypes::Bool
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

and if we know we won't have missing strings, we can disable `uniontypes`:
```@repl 1
e = ExtractString(false)
e("Hello")
e(missing)
e("Hello", store_input=true).metadata
```

## Categorical
```julia
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::Int
	uniontypes::Bool
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

`uniontypes` settings works the same as with scalars or strings.

### Use-cases for unknown value

The last dimension for unknown value can be used e.g. to represent sparse data, where values which are frequent have
their own dimension, and all values which are scarce will share this single dimension. This is useful for heavy-tail 
distributions where many dimensions would be used only rarely, but would raise the number of trained parameters
significantly.

Of course if all values in the training set are represented explicitly and unknown value is not present during training, 
the model will not learn the unknown representation, and it will produce noise in case of unknown value in inference time.

Examples of schema with heavy tail can be following histogram with exponential number of observations
```@example 1
ht_hist = Dict((i==1 ? "aaaaa" : randstring(5))=>ceil(100*ℯ^(-i/5)) for i in 1:1000)
e = JsonGrinder.Entry{String}(ht_hist, sum(values(ht_hist)))
```

Now we can see it has 1000 unique values, and has been created from 1437 observations, where 977 values were observed only once.
Creating the extractor directly and extracting value from it will produce one-hot encoded vector of dimension 1001 (1000 unique values + 1 dimension for the unknown).
```@example 1
ExtractCategorical(filter(kv->kv[2]>=5, e.counts))("aaaaa")
```

But when making threshold for values we have seen at least 5 times:


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
The data of empty bag can be either `missing` or a empty sample, which is more convenient as it makes all samples of the same type, 
which is nicer to AD. This behavior is controlled by `Mill.emptyismissing`. 
The extractor of a `BagNode` can signal to child extractors to extract a sample with zero observations using 
a special singleton `JsonGrinder.extractempty`. 
For example

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


## [Dict](@id exfuctions_ExtractDict)
```julia
struct ExtractDict{S} <: AbstractExtractor
	dict::S
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

Storing input data works in similar manner as for `ExtractArray`, input data are delegated to leaf extractors.

```@repl 1
ex(Dict(:a => "1",
	:c => "A"), store_input=true).metadata
ex(Dict(:a => "1",
	:c => "A"), store_input=true)[:a].metadata
ex(Dict(:a => "1",
	:c => "A"), store_input=true)[:b].metadata
ex(Dict(:a => "1",
	:c => "A"), store_input=true)[:c].metadata
ex(Dict(:a => "1",
	:c => "A"), store_input=true)[:d].metadata
```

or

```@repl 1
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]), store_input=true).metadata
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]), store_input=true)[:a].metadata
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]), store_input=true)[:b].metadata
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]), store_input=true)[:c].metadata
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]), store_input=true)[:d].metadata
ex(Dict(:a => "1",
	:b => "Hello",
	:c => "A",
	:d => ["Hello", "world"]), store_input=true)[:d].data.metadata
```

# Specials

## ExtractKeyAsField
Some JSONs we have encountered use `Dict`s to hold an array of named lists (or other types). 
Having computer security background a prototypical example is storing a list of DLLs with a corresponding list of 
imported function in a single structure. 
For example a JSON
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
JsonGrinder tries to detect these cases, as they are typically manifested by `Dicts` with excessively large number of keys in a schema. 
The detection logic of this case in `suggestextractor(e::DictEntry)` is simple, if the number of unique keys in a specific 
`Dict` is greater than `settings.key_as_field = 500`, such `Dict` is considered to hold values in keys and 
`ExtractKeyAsField` is used instead of `ExtractDict`. 
`key_as_field` can be set to any value based on specific data or domain, but we have found `500` to be reasonable default.

The extractor itself is simple as well. For the case above, it would look like
```@example 1
s = JSON.parse("{ \"foo.dll\" : [\"print\",\"write\", \"open\",\"close\"],
  \"bar.dll\" : [\"send\", \"recv\"]
}")
ex = ExtractKeyAsField(ExtractString(),ExtractArray(ExtractString()))
ex(s)
```

As you might expect, inputs are stored in leaf metadata if needed
```@repl 1
ex(s, store_input=true).metadata
ex(s, store_input=true).data[:key].metadata
ex(s, store_input=true).data[:item].data.metadata
```

Because it returns `BagNode`, missing values are treated in similar manner as in `ExtractArray` and settings of `Mill.emptyismissing` applies here too.

```@example 1
Mill.emptyismissing!(true)
ex(Dict()).data
```

```@example 1
Mill.emptyismissing!(false)
ex(Dict()).data
```

## MultipleRepresentation

Provides a way to have multiple representations for a single value or subtree in JSON. 
For example imagine that are extracting strings with some very frequently occurring values and a lots of clutter, 
which might be important and you do not know about it. 
`MultipleRepresentation(extractors::Tuple)` contains a `Tuple` or `NamedTuple` of extractors and apply them to a single sub-tree in a json. 
The corresponding `Mill` structure will contain `ProductNode` of both representation.

For example `String` with *Categorical* and *NGram* representation will look like
```@example 1
ex = MultipleRepresentation((c = ExtractCategorical(["Hello","world"]), s = ExtractString()))
reduce(catobs,ex.(["Hello","world","from","Prague"]))
```

Because it produces `ProductNode`, missing values are delegated to leaf extractors.
```@example 1
ex(missing)
```

`MultipleRepresentation` together with handling of `missing` values enables `JsonGrinder` to deal with JSONs with non-stable schema.

Minimalistic example of such non-stable schema can be json which sometimes has string and sometimes has array of numbers under same key. 
Let's create appropriate `MultipleRepresentation` (although in real-world usage most suitable `MultipleRepresentation` 
is proposed based on observed data in `suggestextractor`):

```@repl 1
ex = MultipleRepresentation((ExtractString(), ExtractArray(ExtractScalar(Float32))));
e_hello = ex("Hello")
e_hello[:e1].data
e_hello[:e2].data
e_123 = ex([1,2,3])
e_123[:e1].data
e_123[:e2].data
e_2 = ex([2])
e_2[:e1].data
e_2[:e2].data
e_world = ex("world")
e_world[:e1].data
e_world[:e2].data
```

in this example we can see that every time one representation is always missing, and the other one contains data.

## ExtractEmpty

As mentioned in earlier, `ExtractEmpty` is a type used to extract observation with 0 samples. 
There is singleton `extractempty` which can be used to obtain instance of instance of `ExtractEmpty` type.
`StatsBase.nobs(ex(JsonGrinder.extractempty)) == 0` is required to hold for every extractor in order to work correctly.

All above-mentioned extractors are able to extract this, as we can see here

```@repl 1
ExtractString()(JsonGrinder.extractempty)
ExtractString()(JsonGrinder.extractempty) |> nobs
ExtractCategorical(["A","B"])(JsonGrinder.extractempty)
ExtractCategorical(["A","B"])(JsonGrinder.extractempty) |> nobs
ExtractScalar()(JsonGrinder.extractempty)
ExtractScalar()(JsonGrinder.extractempty) |> nobs
ExtractArray(ExtractString())(JsonGrinder.extractempty)
ExtractArray(ExtractString())(JsonGrinder.extractempty) |> nobs
ExtractDict(Dict(:a => ExtractScalar(),
	:b => ExtractString(),
	:c => ExtractCategorical(["A","B"]),
	:d => ExtractArray(ExtractString())))(JsonGrinder.extractempty)
ExtractDict(Dict(:a => ExtractScalar(),
	:b => ExtractString(),
	:c => ExtractCategorical(["A","B"]),
	:d => ExtractArray(ExtractString())))(JsonGrinder.extractempty) |> nobs
```
