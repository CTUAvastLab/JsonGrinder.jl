
"""
	mutable struct Entry <: JSONEntry
		counts::Dict{Any,Int}
		updated::Int
	end

	Keeps statistics about scalar values of a one key and also about items inside a key
	`count` counts how many times given value appeared (at most max_keys is held)
	`updated` counts how many times the entry was updated
"""
mutable struct Entry{T} <: JSONEntry
	counts::Dict{T,Int}
	updated::Int
end

is_numeric(s::AbstractString, T::Type{<:Number}) = tryparse(T, s) isa Number
isfloat(s::AbstractString) = is_numeric(s, Float64)
isint(s::AbstractString) = is_numeric(s, Int64)

Entry(s::T) where {T<:Number} = Entry(Dict{Number,Int}(),0)
function Entry(s::T) where {T<:AbstractString}
	return Entry(Dict{T,Int}(),0)
end

Base.keys(e::Entry) = e.counts |> keys |> collect |> sort
Base.isempty(e::Entry) = false

types(e::Entry) = e.counts |> keys .|> (typeof) |> unique
unify_types(e::Entry) = promote_type(types(e)...)

is_castable(e, T::Type{<:Number}) = unify_types(e) <: AbstractString && e.counts |> keys .|> (x->is_numeric(x, T)) |> all
is_intable(e) = is_castable(e, Int64)
is_floatable(e) = is_castable(e, Float64)
is_numeric_entry(e, T::Type{<:Number}) = unify_types(e) <: T
is_int_entry(e) = is_numeric_entry(e, Integer)
is_float_entry(e) = is_numeric_entry(e, AbstractFloat)

"""
		function update!(a::Entry, v)

		updates the entry when seeing value v
"""
update!(a::Entry{T}, v::Number; path = "") where {T<:Number} = _update!(a, v)
update!(a::Entry{T}, v::AbstractString; path = "") where {T<:AbstractString} = _update!(a, v)
function update!(a::Entry{T}, s::AbstractString; path = "") where {T<:Number}
	return false
end

function _update!(a::Entry, v)
	if length(keys(a.counts)) < max_keys
		a.counts[v] = get(a.counts,v,0) + 1
		# it's there because otherwise, after filling the count keys not even the existing ones are updates
	elseif haskey(a.counts, v)
		a.counts[v] += 1
	end
	a.updated += 1
	return true
end

# todo: try how merging will work with non-stable schema, probably it'll need some fixes
function merge(es::Entry...)
	updates_merged = sum(updated.(es))
	counts_merged = merge(+, counts.(es)...)
	if length(counts_merged) > max_keys
		counts_merged_list = sort(collect(counts_merged), by=x->x[2], rev=true)
		counts_merged = Dict(counts_merged_list[1:max_keys])
	end
	Entry(counts_merged, updates_merged)
end

function merge_inplace!(e::Entry, es::Entry...)
	es = [e; es...]
	updates_merged = sum(updated.(es))
	counts_merged = merge(+, counts.(es)...)
	if length(counts_merged) > max_keys
		counts_merged_list = sort(collect(counts_merged), by=x->x[2], rev=true)
		counts_merged = Dict(counts_merged_list[1:max_keys])
	end
	e.counts = counts_merged
	e.updated = updates_merged
end

function suggestextractor(e::Entry, settings = NamedTuple(); path::String = "")
	t = unify_types(e::Entry)
	t == Any && @error "$(path): JSON does not have a fixed type scheme, quitting"

	for (c, ex) in get(settings, :scalar_extractors, default_scalar_extractor())
		c(e) && return ex(e)
	end
end

function default_scalar_extractor()
	[(e -> (keys_len = length(keys(e)); keys_len / e.updated < 0.1 && keys_len <= 10000),
		e -> ExtractCategorical(keys(e))),
	 (e -> is_intable(e),
		e -> extractscalar(Int64, e)),
	 (e -> is_floatable(e),
	 	e -> extractscalar(Float64, e)),
	(e -> true,
		e -> extractscalar(unify_types(e), e)),]
end

counts(s::T) where {T<:Entry} = s.counts
Base.hash(e::Entry, h::UInt) = hash((e.counts, e.updated), h)
Base.:(==)(e1::Entry, e2::Entry) = e1.updated === e2.updated && e1.counts == e2.counts
sample_synthetic(e::Entry) = first(keys(e.counts))
