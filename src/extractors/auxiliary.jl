"""
	struct AuxiliaryExtractor <: AbstractExtractor
		extractor::AbstractExtractor
		extract_fun::Function
	end

Universal extractor for applying any function,
which lets you ambed any transformation into the AbstractExtractor machinery.
Useful e.g. for extractors accompanying trained models, where you need to apply yet another transformation.

```jldocstest
julia> e1 = ExtractDict(Dict(:a=>ExtractString(), :b=>ExtractString()));

julia> e2 = AuxiliaryExtractor(e1, (e,x)->e[:a](x["a"]))
Auxiliary extractor with
  └── Dict
        ├── a: String
        └── b: String

julia> e2(Dict("a"=>"Hello", "b"=>"World"))
ArrayNode{NGramMatrix{String,Array{String,1},Int64},Nothing}:
 "Hello"
```

"""
struct AuxiliaryExtractor <: AbstractExtractor
	extractor::AbstractExtractor
	extract_fun::Function
end

(e::AuxiliaryExtractor)(x) = e.extract_fun(e.extractor, x)
