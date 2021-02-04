
"""
	struct ExtractDict
		dict::Dict{Symbol,Any}
	end

extracts all items in `dict` and return them as a `Mill.ProductNode`.
If a key is missing in extracted dict, `nothing` is passed to the child extractors.

# Examples

```jldoctest
julia> e = ExtractDict(Dict(:a=>ExtractScalar(Float32, 2, 3), :b=>ExtractCategorical(1:5)))
Dict
  ├── a: Float32
  └── b: Categorical d = 6

julia> res1 = e(Dict("a"=>1, "b"=>1))
ProductNode with 1 obs
  ├── a: ArrayNode(1×1 Array with Float32 elements) with 1 obs
  └── b: ArrayNode(6×1 MaybeHotMatrix with Bool elements) with 1 obs

julia> res1[:a].data
1×1 Array{Float32,2}:
 -3.0

julia> res1[:b].data
6×1 Mill.MaybeHotMatrix{Int64,Int64,Bool}:
 1
 0
 0
 0
 0
 0

julia> res2 = e(Dict("a"=>0))
ProductNode with 1 obs
  ├── a: ArrayNode(1×1 Array with Float32 elements) with 1 obs
  └── b: ArrayNode(6×1 MaybeHotMatrix with Missing elements) with 1 obs

julia> res2[:a].data
1×1 Array{Float32,2}:
 -6.0

julia> res2[:b].data
6×1 Mill.MaybeHotMatrix{Missing,Int64,Missing}:
 missing
 missing
 missing
 missing
 missing
 missing
```
"""
struct ExtractDict{S} <: AbstractExtractor
	dict::S
	function ExtractDict(d::S) where {S<:Dict}
		new{typeof(d)}(d)
	end
end

function Base.getindex(m::ExtractDict, s::Symbol)
	!isnothing(m.dict) && haskey(m.dict, s) && return m.dict[s]
	nothing
end

Base.keys(e::ExtractDict) = keys(e.dict)

replacebyspaces(pad) = map(s -> (s[1], " "^length(s[2])), pad)
(s::ExtractDict)(v::V) where {V<:Nothing} = s(Dict{String,Any}())
(s::ExtractDict)(v)  = s(nothing)


function (s::ExtractDict{S})(v::Dict) where {S<:Dict}
	o = [Symbol(k) => f(get(v,String(k),nothing)) for (k,f) in s.dict]
	ProductNode((; o...))
end

function (s::ExtractDict{S})(ee::ExtractEmpty) where {S<:Dict}
	o = [Symbol(k) => f(ee) for (k,f) in s.dict]
	ProductNode((; o...))
end

extractbatch(extractor, samples) = reduce(catobs, extractor.(samples))

Base.hash(e::ExtractDict, h::UInt) = hash(e.dict, h)
Base.:(==)(e1::ExtractDict, e2::ExtractDict) = e1.dict == e2.dict
