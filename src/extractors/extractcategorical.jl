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
julia> e = ExtractCategorical(2:4, true);

julia> mapreduce(e, catobs, [2,3,1,4]).data
4×4 MaybeHotMatrix{Union{Missing, UInt32},UInt32,Union{Missing, Bool}}:
  true  false  false  false
 false   true  false  false
 false  false  false   true
 false  false   true  false

julia> mapreduce(e, catobs, [1,missing,5]).data
4×3 MaybeHotMatrix{Union{Missing, UInt32},UInt32,Union{Missing, Bool}}:
 false  missing  false
 false  missing  false
 false  missing  false
  true  missing   true

julia> e(4).data
4×1 MaybeHotMatrix{Union{Missing, UInt32},UInt32,Union{Missing, Bool}}:
 false
 false
  true
 false

julia> e(missing).data
4×1 MaybeHotMatrix{Union{Missing, UInt32},UInt32,Union{Missing, Bool}}:
 missing
 missing
 missing
 missing

julia> e = ExtractCategorical(2:4, false);

julia> mapreduce(e, catobs, [2,3,1,4]).data
4×4 Flux.OneHotArray{4,2,Array{UInt32,1}}:
 1  0  0  0
 0  1  0  0
 0  0  0  1
 0  0  1  0

julia> e(4).data
4×1 Flux.OneHotArray{4,2,Array{UInt32,1}}:
 0
 0
 1
 0
```
"""
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::UInt32
	uniontypes::Bool
end

ExtractCategorical(s::Entry, uniontypes = true) = ExtractCategorical(collect(keys(s.counts)), uniontypes)
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

map_val(s, v::MissingOrNothing) = s.uniontypes ? missing : error("This extractor does not support missing values")
map_val(s, v) = get(s.keyvalemap, v, s.n)
stabilize_types_categorical(s::ExtractCategorical{V,I}, x) where {V,I} = s.uniontypes ? Vector{Union{Missing, I}}(x) : x
val2idx(s::ExtractCategorical{V,I}, v::V) where {V,I} = stabilize_types_categorical(s, [map_val(s, v)])
val2idx(s::ExtractCategorical{<:Number,I}, v::Number) where {V,I} = stabilize_types_categorical(s, [map_val(s, v)])
construct(s::ExtractCategorical, x, y) = s.uniontypes ? MaybeHotMatrix(x, y) : OneHotMatrix(x, y)

make_missing_categorical(s::ExtractCategorical, v, store_input) =
    s.uniontypes ?
    _make_array_node(MaybeHotMatrix(stabilize_types_categorical(s, [missing]), s.n), [v], store_input) :
    error("This extractor does not support missing values")

(s::ExtractCategorical{V,I})(v::V; store_input=false) where {V,I} =
	_make_array_node(construct(s, val2idx(s, v), s.n), [v], store_input)

# following 2 methods are to let us extract float from int extractor and vice versa
(s::ExtractCategorical{<:Number,I})(v::Number; store_input=false) where {I} =
	_make_array_node(construct(s, val2idx(s, v), s.n), [v], store_input)

# following 2 methods are to let us extract numeric string from float or int extractor
# I'm trying to parse as float because integer can be parsed as float so I assume all numbers we care about
# are "floatable". Yes, this does not work for
(s::ExtractCategorical{<:Number,I})(v::AbstractString; store_input=false) where {I} =
	_make_array_node(construct(s, val2idx(s, tryparse(FloatType, v)), s.n), [v], store_input)
(s::ExtractCategorical)(v::MissingOrNothing; store_input=false) = make_missing_categorical(s, v, store_input)
(s::ExtractCategorical{V,I})(::ExtractEmpty; store_input=false) where {V,I} =
	ArrayNode(construct(s, s.uniontypes ? Vector{Union{Missing, I}}() : Vector{I}(), s.n))

(s::ExtractCategorical)(v; store_input=false) = make_missing_categorical(s, v, store_input)

Base.hash(e::ExtractCategorical, h::UInt) = hash((e.keyvalemap, e.n, e.uniontypes), h)
Base.:(==)(e1::ExtractCategorical, e2::ExtractCategorical) =
	e1.keyvalemap == e2.keyvalemap && e1.n === e2.n && e1.uniontypes === e2.uniontypes
