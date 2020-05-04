"""
	mutable struct MultiEntry <: JSONEntry
		childs::Vector{Any}
	end

	support for JSON which does not adhere to a fixed type.
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
function suggestextractor(e::MultiEntry, settings = NamedTuple(); path = "")
	# consolidation of types, type wrangling of numeric strings takes place here
	# trying to unify types and create new child entries for them. Merging string + numbers
	e = merge_entries_with_cast(e, Int64, Integer)
	e = merge_entries_with_cast(e, Float64, AbstractFloat)
	MultipleRepresentation(map(i -> suggestextractor(i, settings; path = path),e.childs))
end
