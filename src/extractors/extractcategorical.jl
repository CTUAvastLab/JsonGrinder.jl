import Mill: catobs, MaybeHotMatrix
"""
	ExtractCategorical(s::Entry)
	ExtractCategorical(s::UnitRange)
	ExtractCategorical(s::Vector)

Converts a single item to a one-hot encoded vector.
Converts array of items into matrix of one-hot encoded columns.
There is always alocated an extra element for a unknown value.
If passed `missing`, returns column of missing values.

# Examples

```jldoctest
julia> e = ExtractCategorical(2:4);
julia> e([2,3,1,4]).data
4×4 MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}:
 1  0  0  0
 0  1  0  0
 0  0  0  1
 0  0  1  0

julia> e([1,missing,5]).data
4×3 MaybeHotMatrix{Union{Missing, Int64},Array{Union{Missing, Int64},1},Int64,Union{Missing, Bool}}: false  missing  false
 false  missing  false
 false  missing  false
  true  missing   true

julia> e(4).data
4×1 MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}:
 0
 0
 1
 0

julia> e(missing).data
4×1 MaybeHotMatrix{Missing,Array{Missing,1},Int64,Missing}:
 missing
 missing
 missing
 missing
```
"""
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::Int
end

ExtractCategorical(s::Entry) = ExtractCategorical(collect(keys(s.counts)))
ExtractCategorical(s::UnitRange) = ExtractCategorical(collect(s))
function ExtractCategorical(ks::Vector)
	if isempty(ks)
		@warn "Skipping initializing empty categorical variable does not make much sense to me"
		return nothing
	end
	ks = sort(unique(ks))
	ExtractCategorical(Dict(zip(ks, 1:length(ks))), length(ks) +1)
end

function (s::ExtractCategorical{V,I})(v::V) where {V,I}
    x = MaybeHotMatrix([get(s.keyvalemap, v, s.n)], s.n)
    ArrayNode(x)
end

function (s::ExtractCategorical{V,I})(vs::Vector{V}) where {V,I}
	x = MaybeHotMatrix([get(s.keyvalemap, v, s.n) for v in vs], s.n)
	ArrayNode(x)
end

# following 2 methods are to let us extract float from int extractor and vice versa
function (s::ExtractCategorical{U,I})(v::V) where {U<:Number,V<:Number,I}
    x = MaybeHotMatrix([get(s.keyvalemap, v, s.n)], s.n)
    ArrayNode(x)
end

function (s::ExtractCategorical{U,I})(vs::Vector{V}) where {U<:Number,V<:Number,I}
	x = MaybeHotMatrix([get(s.keyvalemap, v, s.n) for v in vs], s.n)
	ArrayNode(x)
end

function (s::ExtractCategorical{V,I})(vs::Vector{<:Union{V, Missing, Nothing}}) where {V,I}
	x = MaybeHotMatrix([ismissing(v) || isnothing(v) ? missing : get(s.keyvalemap, v, s.n) for v in vs], s.n)
	ArrayNode(x)
end

# todo: dodělat missingy, všchny nothing předělat na missing a pořádně to otestovat
(s::ExtractCategorical)(::V) where {V<:Union{Missing, Nothing}} = ArrayNode(MaybeHotMatrix([missing], s.n))
(s::ExtractCategorical)(::ExtractEmpty) = ArrayNode(MaybeHotMatrix(Vector{Int}(), s.n))
(s::ExtractCategorical)(v) = s(missing)

Base.reduce(::typeof(catobs), a::Vector{S}) where {S<:Flux.OneHotMatrix} = _catobs(a[:])
catobs(a::Flux.OneHotMatrix...) = _catobs(collect(a))
_catobs(a::AbstractArray{<:Flux.OneHotMatrix}) = Flux.OneHotMatrix(a[1].height,reduce(vcat, [i.data for i in a]))

Base.hash(e::ExtractCategorical, h::UInt) = hash((e.keyvalemap, e.n), h)
Base.:(==)(e1::ExtractCategorical, e2::ExtractCategorical) = e1.keyvalemap == e2.keyvalemap && e1.n === e2.n
