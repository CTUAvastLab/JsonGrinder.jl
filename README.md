# JsonGrinder

[![Build Status](https://travis-ci.org/Pevnak/JsonGrinder.jl.svg?branch=master)](https://travis-ci.org/Pevnak/JsonGrinder.jl)
[![Coverage Status](https://coveralls.io/repos/github/pevnak/JsonGrinder.jl/badge.svg?branch=master)](https://coveralls.io/github/pevnak/JsonGrinder.jl?branch=master)
[![codecov.io](http://codecov.io/github/Pevnak/JsonGrinder.jl/coverage.svg?branch=master)](http://codecov.io/github/Pevnak/JsonGrinder.jl?branch=master)




**JsonGrinder** is a collection of routines that facilitates conversion of JSON documents into structures used by `Mill.jl` project.

The envisioned workflow is as follows:
	1. Estimate schema of documents from a collection of JSON documents using a call `schema`.
	2. Create an extractor using `extractor = suggestextractor(schema, settings)`
	3. Conver JSONs to Mill friendly structures using `extractbatch(extractor, samples) = reduce(catobs, map(s-> extractor(s), samples))`


A simplest example would looks as follows:
Let's start by importing libraries and defining some JSONs.
```julia
using JsonGrinder, Flux, Mill, JSON
j1 = JSON.parse("""{"a": 1, "b": "hello works", "c":{ "a":1 ,"b": "hello world"}}""")
j2 = JSON.parse("""{"a": 2, "b": "hello world", "c":{ "a":2 ,"b": "hello"}}""")
```

Let's estimate a schema from those two documents
```julia
julia> sch = schema([j1,j2])
: [Dict]
  ├── a: [Scalar - Int64], 2 unique values, updated = 2
  ├── b: [Scalar - String], 2 unique values, updated = 2
  └── c: [Dict]
      ├── a: [Scalar - Int64], 2 unique values, updated = 2
      └── b: [Scalar - String], 2 unique values, updated = 2
```

Let's create a default extractor
```julia
julia> extractor = suggestextractor(sch)
: struct
  ├─── a: Int64
  ├─── b: String
  └─── c: struct
        ├─── a: Int64
        └─── b: String
```

Now we can convert the data to data either by
```julia
ds = map(s-> extractor(s), [j1,j2])
dss = reduce(catobs, ds)
```
or for convenience joined into a single command
```julia
julia> ds = extractbatch(extractor, [j1, j2])
TreeNode
  ├── scalars: ArrayNode(1, 2)
  ├── c: TreeNode
  │     ├── scalars: ArrayNode(1, 2)
  │     └── b: ArrayNode(2053, 2)
  └── b: ArrayNode(2053, 2)
```

Now, we use a convenient function `reflectinmodel` which creates a model that can process our dataset
```julia
julia> m = reflectinmodel(ds, d -> Chain(Dense(d,10, relu), Dense(10,4)))
ProductModel (
  ├── scalars: ArrayModel(Chain(Dense(1, 10, relu), Dense(10, 4)))
  ├── c: ProductModel (
  │     ├── scalars: ArrayModel(Chain(Dense(1, 10, relu), Dense(10, 4)))
  │     └── b: ArrayModel(Chain(Dense(2053, 10, relu), Dense(10, 4)))
  │    ) ↦  ArrayModel(Chain(Dense(8, 10, relu), Dense(10, 4)))
  └── b: ArrayModel(Chain(Dense(2053, 10, relu), Dense(10, 4)))
 ) ↦  ArrayModel(Chain(Dense(12, 10, relu), Dense(10, 4)))
```

and finally, we can do all the usual stuff with it
```julia
julia> m(ds).data
4×2 Array{Float32,2}:
  0.102617    0.116041
  0.0478762   0.133312
  0.0357873  -0.0108712
 -0.0197168  -0.0255238
 ```

* Customization of extractors:

While extractors of Dictionaries and Lists are straighforward, as the first one is converted to `Mill.ProductNode` and the latter to `Mill.BagNode`. The extractor of scalars can benefit from customization. This can be to some extent automatized by defining its own conversion rules in a list of [(criterion, extractor),...] where criterion is a function accepting `JsonEntry` and outputing `true` and `false` and extractor is a function of `JsonEntry` again returning a function extracting given entry. This list is passed to `suggestextractor(schema, (scalar_extractors = [(criterion, extractor),...]))`

For example a default list of extractors is
```julia
function default_scalar_extractor()
	[(e -> (length(keys(e.counts)) / e.updated < 0.1  && length(keys(e.counts)) <= 10000),
		e -> ExtractCategorical(collect(keys(e.counts)))),
	(e -> true,
		e -> extractscalar(promote_type(unique(typeof.(keys(e.counts)))...))),]
end
```
where the first entry checks sparsity `e -> (length(keys(e.counts)) / e.updated < 0.1  && length(keys(e.counts)) <= 10000)` and if it is sufficiently sparse, it will suggest Categorical (one-hot) extractor. The second is a catch-all case, which extracts a scalar value, such as Float32.
