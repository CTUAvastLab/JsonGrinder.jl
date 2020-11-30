# Extractors

Extractors are responsible for converting json elements to Mill structures. Missing values are automatically handled by `Mill.jl`.

## Scalar values
Scalar values can be represented either as numbers, categorical variables (one-hot encoded), or String. Each of these have a special extractor.

```julia
	struct ExtractScalar{T}
		datatype::Type{T}
		c::T
		s::T
	end
```
converts numerical values to type `T`, subtract `c` and multiplies it by `s`. Strings are converted to numbers.

`ExtractScalar(e::Entry)` initializes a scalar extractor such that the extracted values are in interval `[0,1]`. Strings containing exclusively numerical values are treated as numbers.
```juliadoc
julia> e = ExtractScalar(Float32, 0.5, 4.0)
Float32

julia> e(1)
ArrayNode(1, 1)

julia> e(1).data
1×1 Array{Float64,2}:
 2.0
```

```julia
	struct ExtractString{T}
		datatype::Type{T}
		n::Int
		b::Int
		m::Int
	end
```
Represent `String` as `n-`grams (`NGramMatrix` from `Mill.jl`) with base `b` and modulo `m`.

`ExtractString(e::Entry)` / `ExtractScalar(e::Entry)` initializes the extractor with `n = 3, b = 256, m = 2053`.

```juliadoc
julia> e = ExtractString(String)
String

julia> e("Hello")
ArrayNode(2053, 1)
```


```julia
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::Int
end
```
Converts a single item to a one-hot encoded vector. There is always alocated an extra element for a unknown value. 


	ExtractCategorical(s::Entry)
	ExtractCategorical(s::UnitRange)
	ExtractCategorical(s::Vector)
