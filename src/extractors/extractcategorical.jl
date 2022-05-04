import Flux: OneHotMatrix
import Mill: ArrayNode, MaybeHotMatrix
"""
	struct ExtractCategorical{V,I} <: AbstractExtractor
		keyvalemap::Dict{V,I}
		n::Int
		uniontypes::Bool
	end
	ExtractCategorical(s::Entry, uniontypes = true)
	ExtractCategorical(s::UnitRange, uniontypes = true)
	ExtractCategorical(s::Vector, uniontypes = true)

Converts a single item to a one-hot encoded vector.
Converts array of items into matrix of one-hot encoded columns.
There is always alocated an extra element for a unknown value.
If passed `missing`, if `uniontypes` is true, returns column of missing values, otherwise raises error.
If `uniontypes` is true, it allows extracting `missing` values and all extracted values will be of type
`Union{Missing, <other type>}` due to type stability reasons. Otherwise missings extraction is not allowed.

# Examples

```jldoctest
julia> using Mill: catobs

julia> e = ExtractCategorical(2:4, true);

julia> mapreduce(e, catobs, [2,3,1,4]).data
4×4 MaybeHotMatrix with eltype Union{Missing, Bool}:
  true    ⋅      ⋅      ⋅
   ⋅     true    ⋅      ⋅
   ⋅      ⋅      ⋅     true
   ⋅      ⋅     true    ⋅

julia> mapreduce(e, catobs, [1,missing,5]).data
4×3 MaybeHotMatrix with eltype Union{Missing, Bool}:
   ⋅    missing    ⋅
   ⋅    missing    ⋅
   ⋅    missing    ⋅
  true  missing   true

julia> e(4).data
4×1 MaybeHotMatrix with eltype Union{Missing, Bool}:
   ⋅
   ⋅
  true
   ⋅

julia> e(missing).data
4×1 MaybeHotMatrix with eltype Union{Missing, Bool}:
 missing
 missing
 missing
 missing

julia> e = ExtractCategorical(2:4, false);

julia> mapreduce(e, catobs, [2,3,1,4]).data
4×4 OneHotMatrix(::Vector{UInt32}) with eltype Bool:
 1  ⋅  ⋅  ⋅
 ⋅  1  ⋅  ⋅
 ⋅  ⋅  ⋅  1
 ⋅  ⋅  1  ⋅

julia> e(4).data
4×1 OneHotMatrix(::Vector{UInt32}) with eltype Bool:
 ⋅
 ⋅
 1
 ⋅
```
"""
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::UInt32
	uniontypes::Bool
end

ExtractCategorical(s::Base.KeySet, uniontypes = true) = ExtractCategorical(collect(s), uniontypes)
ExtractCategorical(s::Entry, uniontypes = true) = ExtractCategorical(keys(s.counts), uniontypes)
ExtractCategorical(s::UnitRange, uniontypes = true) = ExtractCategorical(collect(s), uniontypes)
function ExtractCategorical(ks::Vector, uniontypes = true)
	if isempty(ks)
		@warn "Skipping initializing empty categorical variable does not make much sense to me"
		return nothing
	end
	ks = sort(unique(ks))
	keys_len = length(ks)
	if keys_len > typemax(UInt32)
		@error "Dictionary is too big, we support uint32 types"
	end
	# keeping int32 indices, because it's faster than int64 and int64 is too big to be usable anyway
	ExtractCategorical(Dict(zip(ks, UInt32(1):UInt32(keys_len))), UInt32(keys_len + 1), uniontypes)
end

map_val(s, ::MissingOrNothing) = s.uniontypes ? missing : error("This extractor does not support missing values")
# bugfix for https://github.com/CTUAvastLab/JsonGrinder.jl/issues/100
map_val(s, v) = get(s.keyvalemap, shorten_if_str(v), s.n)
stabilize_types_categorical(s::ExtractCategorical{V,I}, x) where {V,I} = s.uniontypes ? Vector{Union{Missing, I}}(x) : x
val2idx(s::ExtractCategorical{V,I}, v::V) where {V,I} = stabilize_types_categorical(s, [map_val(s, v)])
val2idx(s::ExtractCategorical{<:Number,I}, v::Number) where {V,I} = stabilize_types_categorical(s, [map_val(s, v)])
construct(s::ExtractCategorical, x, y) = s.uniontypes ? MaybeHotMatrix(x, y) : OneHotMatrix(x, y)

make_missing_categorical(s::ExtractCategorical, v, store_input) =
    s.uniontypes ?
    _make_array_node(MaybeHotMatrix(stabilize_types_categorical(s, [missing]), s.n), [v], store_input) :
    error("This extractor does not support missing values")

(s::ExtractCategorical{V})(v::V; store_input=false) where {V<:HierarchicType} =
	_make_array_node(construct(s, val2idx(s, v), s.n), [v], store_input)
# I need to define this in order to disambiguate the method with different numbers compared to HierarchicType
(s::ExtractCategorical{V})(v::V; store_input=false) where {V<:Number} =
	_make_array_node(construct(s, val2idx(s, v), s.n), [v], store_input)

# following 2 methods are to let us extract float from int extractor and vice versa
(s::ExtractCategorical{<:Number})(v::Number; store_input=false) =
	_make_array_node(construct(s, val2idx(s, v), s.n), [v], store_input)

# following 2 methods are to let us extract numeric string from float or int extractor
# I'm trying to parse as float because integer can be parsed as float so I assume all numbers we care about
# are "floatable". Yes, this does not work for
(s::ExtractCategorical{<:Number})(v::AbstractString; store_input=false) =
	_make_array_node(construct(s, val2idx(s, tryparse(FloatType, v)), s.n), [v], store_input)
(s::ExtractCategorical)(v::MissingOrNothing; store_input=false) = make_missing_categorical(s, v, store_input)
(s::ExtractCategorical{V,I})(::ExtractEmpty; store_input=false) where {V,I} =
	ArrayNode(construct(s, s.uniontypes ? Vector{Union{Missing, I}}() : Vector{I}(), s.n))

# todo: this is more specific than V, V method and we need to fix it
(s::ExtractCategorical)(v::HierarchicType; store_input=false) = make_missing_categorical(s, v, store_input)

Base.hash(e::ExtractCategorical, h::UInt) = hash((e.keyvalemap, e.n, e.uniontypes), h)
Base.:(==)(e1::ExtractCategorical, e2::ExtractCategorical) =
	e1.keyvalemap == e2.keyvalemap && e1.n === e2.n && e1.uniontypes === e2.uniontypes
