"""
	mutable struct DictEntry <: JSONEntry
		childs::Dict{String, Any}
		updated::Int
	end

keeps statistics about an object in json
- `childs` maintains key-value statistics of childrens. All values should be JSONEntries
- `updated` counts how many times the struct was updated.
"""

mutable struct DictEntry <: JSONEntry
	childs::Dict{Symbol, Any}
	updated::Int
end

DictEntry() = DictEntry(Dict{Symbol,Any}(),0)
Base.getindex(s::DictEntry, k::Symbol) = s.childs[k]
Base.setindex!(s::DictEntry, i, k::Symbol) = s.childs[k] = i
Base.get(s::Dict{Symbol, <:Any}, key::String, default) = get(s, Symbol(key), default)
Base.keys(e::DictEntry) = keys(e.childs)
Base.isempty(e::DictEntry) = isempty(e.childs)

function update!(s::DictEntry, d::AbstractDict; path = "")
	s.updated += 1
	for (k,v) in d
		kc = Symbol(k)
		isnothing(v) && continue
		# isempty(v) && continue
		if haskey(s.childs, kc)
			s.childs[kc] = safe_update!(s.childs[kc], v, path="$path[$k]")
		else
			o = newentry!(v)
			if !isnothing(o)
				s.childs[kc] = o
			end
		end
	end
	return true
end

"""
	suggestextractor(e::DictEntry, settings = NamedTuple())

create convertor of json to tree-structure of `DataNode`

- `e` top-level of json hierarchy, typically returned by invoking schema
- `settings` can be any container supporting `get` function
- `settings.mincountkey` contains minimum repetition of the key to be included into the extractor
  (if missing it is equal to zero)
- `settings.key_as_field` of the number of keys exceeds this value, it is assumed that keys contains a value,
  which means that they will be treated as strings.
- `settings.scalar_extractors` contains rules for determining which extractor to use for leaves.
  Default value is return value of `default_scalar_extractor()`, it's array of pairs where first element is predicate
  and if it matches, second element, function which maps schema to specific extractor, is called.
"""
function suggestextractor(e::DictEntry, settings = NamedTuple(); path = "", child_less_than_parent = false)
	length(e.childs) >= get(settings, :key_as_field, 500) && return key_as_field(e, settings;
		path = path, child_less_than_parent = child_less_than_parent)

	for k in filter(k->!isnothing(e.childs[k]) && isempty(e.childs[k]), keys(e.childs))
		@warn "$(path): key $k contains empty array, skipping"
	end
	ks = filter(k->!isempty(e.childs[k]), keys(e.childs))
	mincount = get(settings, :mincountkey, 0)
	ks = filter(k -> updated(e.childs[k]) > mincount, ks)
	isempty(ks) && return nothing
	c = [(k,suggestextractor(e.childs[k], settings,
			path = path*"[:$(k)]",
			child_less_than_parent = child_less_than_parent || e.updated > e.childs[k].updated)
		) for k in ks]
	c = filter(s -> s[2] != nothing, c)
	isempty(c) && return nothing
	ExtractDict(Dict(c))
end

function key_as_field(e::DictEntry, settings; path = "", child_less_than_parent = false)
	@info "$(path) seems to store values in keys, therefore node is treated as bag with keys as extra values."
	child_schema = reduce(merge, collect(values(e.childs)), init = nothing)
	key_schema = Entry(String(first(keys(e))))
	for k in keys(e)
		update!(key_schema, k, path=path)
	end
	ExtractKeyAsField(ExtractString(3, 256, 2053, true), suggestextractor(child_schema, settings, path = path*"[:childs]"))
end

"""
Dispatch of Base.merge on JsonGrinder.JSONEntry structures.
Allows to merge multiple schemas to single one.

	merge(es::Entry...)
	merge(es::DictEntry...)
	merge(es::ArrayEntry...)
	merge(es::MultiEntry...)
	merge(es::JsonGrinder.JSONEntry...)

it can be used to distribute calculation of schema across multiple workers to merge their partial results into bigger one.

# Example

If we want to calculate schema from e.g. array of jsons in a distributed manner, if we have `jsons` array and ,
we can do it using
```julia
using ThreadsX
ThreadsX.mapreduce(schema, merge, Iterators.partition(jsons, length(jsons) ÷ Threads.nthreads()))
```
or
```julia
using ThreadTools
merge(tmap(schema, Threads.nthreads(), Iterators.partition(jsons, length(jsons) ÷ Threads.nthreads()))
```
or, if you like to split it into multiple jobs and having them processed by multiple threads, it can look like
```julia
using ThreadTools
merge(tmap(schema, Threads.nthreads(), Iterators.partition(jsons, 1_000))
```
where we split array to smaller array of size 1k and let all available threads create partial schemas.

If your data is too large to fit into ram, following approach works well also with filenames and similar other ways to process large data.
"""
function merge(es::DictEntry...)
	updates_merged = sum(updated.(es))
	childs_merged = merge(merge, childs.(es)...)
	DictEntry(childs_merged, updates_merged)
end

childs(s::T) where {T<:DictEntry} = s.childs
Base.hash(e::DictEntry, h::UInt) = hash((e.childs, e.updated), h)
Base.:(==)(e1::DictEntry, e2::DictEntry) = e1.updated === e2.updated && e1.childs == e2.childs

sample_synthetic(e::DictEntry) = Dict(k => sample_synthetic(v) for (k, v) in e.childs)
