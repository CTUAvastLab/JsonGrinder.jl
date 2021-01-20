"""
		mutable struct DictEntry <: JSONEntry
			childs::Dict{String,Any}
			updated::Int
		end

		keeps statistics about an object in json
		`childs` maintains key-value statistics of childrens. All values should be JSONEntries
		`updated` counts how many times the struct was updated.
"""

mutable struct DictEntry <: JSONEntry
	childs::Dict{Symbol, Any}
	updated::Int
end

DictEntry() = DictEntry(Dict{Symbol,Any}(),0)
Base.getindex(s::DictEntry, k::Symbol) = s.childs[k]
Base.setindex!(s::DictEntry, i, k::Symbol) = s.childs[k] = i
Base.get(s::Dict{Symbol, <:Any}, key::String, default) = get(s, Symbol(key), default)
Base.isempty(e::DictEntry) = false
Base.keys(e::DictEntry) = keys(e.childs)

function update!(s::DictEntry, d::Dict; path = "")
	s.updated +=1
	for (k,v) in d
		kc = Symbol(k)
		v == nothing && continue
		isempty(v) && continue
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

		`e` top-level of json hierarchy, typically returned by invoking schema
		`settings.mincount` contains minimum repetition of the key to be included into
		the extractor (if missing it is equal to zero)
		`settings.key_as_field` of the number of keys exceeds this value, it is assumed that
		keys contains a value, which means that they will be treated as strings.
		`settings` can be any container supporting `get` function
"""
function suggestextractor(e::DictEntry, settings = NamedTuple(); path = "")
	length(e.childs) >= get(settings, :key_as_field, 500) && return(key_as_field(e, settings; path = path))

	mincount = get(settings, :mincount, 0)
	ks = filter(k -> updated(e.childs[k]) > mincount, keys(e.childs))
	# to omit empty lists by default
	ks = filter(k->!isempty(e.childs[k]), keys(e.childs))
	for k in filter(k->isempty(e.childs[k]), keys(e.childs))
		@warn "$(path): key $k contains empty array, skipping"
	end
	isempty(ks) && return nothing
	c = [(k,suggestextractor(e.childs[k], settings, path = path*"[:$(k)]")) for k in ks]
	c = filter(s -> s[2] != nothing, c)
	isempty(c) && return nothing
	ExtractDict(Dict(c))
end

function key_as_field(e::DictEntry, settings; path = "")
	@info "$(path) seems to store values in keys, therefore node is treated as bag with keys as extra values."
	child_schema = reduce(merge, collect(values(e.childs)), init = nothing)
	key_schema = Entry(String(first(keys(e))))
	for k in keys(e)
		update!(key_schema, k, path=path)
	end
	ExtractKeyAsField(ExtractString(3, 256, 2053), suggestextractor(child_schema, settings, path = path*"[:childs]"))
end

function merge(es::DictEntry...)
	updates_merged = sum(updated.(es))
	childs_merged = merge(merge, childs.(es)...)
	DictEntry(childs_merged, updates_merged)
end

childs(s::T) where {T<:DictEntry} = s.childs
Base.hash(e::DictEntry, h::UInt) = hash((e.childs, e.updated), h)
Base.:(==)(e1::DictEntry, e2::DictEntry) = e1.updated === e2.updated && e1.childs == e2.childs

_extract_missing(empty_dict_vals, parent_updated, child) =
	empty_dict_vals && (parent_updated > child.updated) && child isa Entry
sample_synthetic(e::DictEntry; empty_dict_vals=false) = Dict(
	k => _extract_missing(empty_dict_vals, e.updated, v) ? missing : sample_synthetic(v, empty_dict_vals=empty_dict_vals)
	for (k, v) in e.childs)
