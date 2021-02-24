"""
	mutable struct MultiEntry <: JSONEntry
		childs::Vector{Any}
	end

support for JSON which does not adhere to a fixed type.
Container for multiple types of entry which are observed on the same place in JSON.
"""
mutable struct MultiEntry <: JSONEntry
	childs::Vector{JSONEntry}
	updated::Int
end

MultiEntry(s::MultiEntry) = s
MultiEntry(s::Vector{T}) where {T<:MultiEntry} = only(s)

Base.getindex(s::MultiEntry, k::Int) = s.childs[k]
Base.setindex!(s::MultiEntry, i, k::Int) = s.childs[k] = i
Base.isempty(e::MultiEntry) = isempty(e.childs)
Base.keys(e::MultiEntry) = collect(1:length(e.childs))


function update!(s::MultiEntry, d; path = "")
	s.updated += 1
	for (i, c) in enumerate(s.childs)
		update!(c, d, path="$path[$i]") && return true
	end
	new_child = safe_update!(newentry(d), d, path=path)
	push!(s.childs, new_child)
	return true
end

findfirst_with_el(testf::Function, A) = (idx = findfirst(testf, A); (idx, A[idx]))
tryparse_entry_keys(e::Entry, T::Type) = Entry(Dict(tryparse(T, k)=>v for (k, v) in e.counts), e.updated)
function merge_entries_with_cast(e::MultiEntry, concrete_type, abstract_type)
	leaf_entries = filter(x->x isa Entry, e.childs)
	if any(is_numeric_entry.(leaf_entries, abstract_type)) && any(is_castable.(leaf_entries, concrete_type))
		e_new = MultiEntry(copy(e.childs), e.updated)
		to_merge_idx, to_merge = findfirst_with_el(x->is_castable(x, concrete_type), e_new.childs)
		to_merge_into_idx, to_merge_into = findfirst_with_el(x->is_numeric_entry(x, abstract_type), e_new.childs)
		new_entry = tryparse_entry_keys(to_merge, concrete_type)
		merged_entry = merge(to_merge_into, new_entry)
		deleteat!(e_new.childs, sort([to_merge_idx, to_merge_into_idx]))
		push!(e_new.childs, merged_entry)
		return e_new
	end
	e
end

# todo: benchmark on large cuckoo schemas, and optimize if needed
function suggestextractor(e::MultiEntry, settings = NamedTuple(); path = "", child_less_than_parent = false)
	# consolidation of types, type wrangling of numeric strings takes place here
	# trying to unify types and create new child entries for them. Merging string + numbers
	e = merge_entries_with_cast(e, Int32, Real)
	e = merge_entries_with_cast(e, FloatType, Real)
	# we need to filter out empty things in multientry too, same manner as dict
	ks = filter(k->!isempty(e.childs[k]), keys(e.childs))
	# child extractors of multi representation will always gene incompatible type which is treated as missing
	# otherwise there would not be the need for MultiRepresentation at all
	# that's why we enforce true here
	MultipleRepresentation(map(k -> suggestextractor(e.childs[k], settings,
			path = path,
			child_less_than_parent = true
		),ks))
end

function merge(es::MultiEntry...)
	updates_merged = sum(updated.(es))
	entries = childs.(es) |> Iterators.flatten |> collect
	entry_types = entries .|> typeof |> unique
	merged_childs = [merge(filter(x->x isa t, entries)...) for t in entry_types]
	MultiEntry(merged_childs, updates_merged)
end

# this is merging of different types, merging them
function merge(es::JSONEntry...)
	multi_entries = filter(e->e isa MultiEntry, es)
	multi_entry = if isempty(multi_entries)
		MultiEntry([], 0)
	else
		merge(multi_entries...)
	end

	other_entries = filter(e->!(e isa MultiEntry), es)
	updates_merged = sum(updated.(other_entries))
	multi_entry.updated += updates_merged
	entry_types = other_entries .|> typeof |> unique
	merged_entries = [merge(filter(x->x isa t, other_entries)...) for t in entry_types]
	multi_entry_types = map(typeof, multi_entry.childs)
	for e in merged_entries
		idx = findfirst(x->e isa x, multi_entry_types)
		if isnothing(idx)
			push!(multi_entry.childs, e)
		else
			multi_entry.childs[idx] = merge(multi_entry.childs[idx], e)
		end
	end
	multi_entry
end

childs(s::T) where {T<:MultiEntry} = s.childs
Base.hash(e::MultiEntry, h::UInt) = hash((e.childs, e.updated), h)
Base.:(==)(e1::MultiEntry, e2::MultiEntry) = e1.updated === e2.updated && e1.childs == e2.childs
sample_synthetic(e::MultiEntry; empty_dict_vals=false, child_less_than_parent=false) =
	[sample_synthetic(v; empty_dict_vals, child_less_than_parent) for v in e.childs]
