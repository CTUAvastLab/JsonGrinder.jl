"""
		mutable struct ArrayEntry <: JSONEntry
			items
			l::Dict{Int,Int}
			updated::Int
		end

		keeps statistics about an array entry in JSON.
		`items` is typeof `Entry` or nothing and keeps statistics about the elements of the array
		`l` keeps histogram of message length
		`updated` counts how many times the struct was updated.
"""
mutable struct ArrayEntry <: JSONEntry
	items
	l::Dict{Int,Int}
	updated::Int
end

ArrayEntry(items) = ArrayEntry(items,Dict{Int,Int}(),0)
Base.isempty(e::ArrayEntry) = e.items isa ArrayEntry ? isempty(e.items) : isnothing(e.items)

function update!(a::ArrayEntry, b::Vector; path = "")
	n = length(b)
	a.updated +=1
	a.l[n] = get(a.l,n,0) + 1
	n == 0 && return
	if isnothing(a.items)
		 a.items = newentry(b).items
	end

	for (i, v) in enumerate(b)
		a.items = safe_update!(a.items,v,path="$path[$i]")
	end
	return true
end

function suggestextractor(node::ArrayEntry, settings = NamedTuple(); path = "")
	if isempty(node)
		@warn "$(path) is an empty array, therefore I can not suggest extractor."
		return nothing
	end

	if length(node.l) == 1 && typeof(node.items) <: Entry && promote_type(unique(typeof.(keys(node.items.counts)))...) <: Number
		@info "$(path) is an array of numbers with of same length, therefore it will be treated as a vector."
		return ExtractVector(only(collect(keys(node.l))))
	end
	e = suggestextractor(node.items, settings, path = path)
	isnothing(e) ? e : ExtractArray(e)
end

function merge(es::ArrayEntry...)
	updates_merged = sum(updated.(es))
	l_merged = merge(+, l.(es)...)
	nonempty_items = items.(filter(!isempty, collect(es)))
	items_merged = isempty(nonempty_items) ? nothing : merge(merge, nonempty_items...)
	ArrayEntry(items_merged, l_merged, updates_merged)
end

l(s::T) where {T<:ArrayEntry} = s.l
items(s::T) where {T<:ArrayEntry} = s.items
Base.hash(e::ArrayEntry, h::UInt) = hash((e.items, e.l, e.updated), h)
Base.:(==)(e1::ArrayEntry, e2::ArrayEntry) = e1.updated === e2.updated && e1.l == e2.l && e1.items == e2.items
sample_synthetic(e::ArrayEntry; empty_dict_vals=false) = repeat([sample_synthetic(e.items, empty_dict_vals=empty_dict_vals)], 2)
