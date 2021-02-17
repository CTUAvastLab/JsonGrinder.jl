import Mill: ArrayNode, MaybeHotMatrix
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
4×4 Mill.MaybeHotMatrix{Int64,Int64,Bool}:
 1  0  0  0
 0  1  0  0
 0  0  0  1
 0  0  1  0

julia> e([1,missing,5]).data
4×3 Mill.MaybeHotMatrix{Union{Missing, Int64},Int64,Union{Missing, Bool}}:
 false  missing  false
 false  missing  false
 false  missing  false
  true  missing   true

julia> e(4).data
4×1 Mill.MaybeHotMatrix{Int64,Int64,Bool}:
 0
 0
 1
 0

julia> e(missing).data
4×1 Mill.MaybeHotMatrix{Missing,Int64,Missing}:
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

(s::ExtractCategorical{V,I})(v::V) where {V,I} =
    _make_array_node(MaybeHotMatrix([get(s.keyvalemap, v, s.n)], s.n), v, store_input)

(s::ExtractCategorical{V,I})(vs::Vector{V}; store_input=false) where {V,I} =
	_make_array_node(MaybeHotMatrix([get(s.keyvalemap, v, s.n) for v in vs], s.n), vs, store_input)

# following 2 methods are to let us extract float from int extractor and vice versa
(s::ExtractCategorical{U,I})(v::V; store_input=false) where {U<:Number,V<:Number,I} =
    _make_array_node(MaybeHotMatrix([get(s.keyvalemap, v, s.n)], s.n), v, store_input)

(s::ExtractCategorical{U,I})(vs::Vector{V}; store_input=false) where {U<:Number,V<:Number,I} =
	_make_array_node(MaybeHotMatrix([get(s.keyvalemap, v, s.n) for v in vs], s.n), vs, store_input)

# following 2 methods are to let us extract numeric string from float or int extractor
# I'm trying to parse as float because integer can be parsed as float so I assume all numbers we care about
# are "floatable". Yes, this does not work for
(s::ExtractCategorical{U,I})(v::V; store_input=false) where {U<:Number,V<:AbstractString,I} =
    _make_array_node(MaybeHotMatrix([get(s.keyvalemap, tryparse(FloatType, v), s.n)], s.n), vs, store_input)

(s::ExtractCategorical{U,I})(vs::Vector{V}; store_input=false) where {U<:Number,V<:AbstractString,I} =
	_make_array_node(MaybeHotMatrix([get(s.keyvalemap, tryparse(FloatType, v), s.n) for v in vs], s.n), vs, store_input)

function (s::ExtractCategorical{V,I})(vs::Vector{<:Union{V, Missing, Nothing}}; store_input=false) where {V,I}
	x = MaybeHotMatrix([ismissing(v) || isnothing(v) ? missing : get(s.keyvalemap, v, s.n) for v in vs], s.n)
	_make_array_node(x, vs, store_input)
end


make_missing(s::ExtractCategorical, v, store_input) = _make_array_node(MaybeHotMatrix([missing], s.n), v, store_input)
(s::ExtractCategorical)(v::MissingOrNothing; store_input=false) = make_missing(s, v, store_input)
(s::ExtractCategorical)(::ExtractEmpty; store_input=false) = ArrayNode(MaybeHotMatrix(Vector{Int}(), s.n))
(s::ExtractCategorical)(v; store_input=false) = make_missing(s, v, store_input)

Base.hash(e::ExtractCategorical, h::UInt) = hash((e.keyvalemap, e.n), h)
Base.:(==)(e1::ExtractCategorical, e2::ExtractCategorical) = e1.keyvalemap == e2.keyvalemap && e1.n === e2.n
