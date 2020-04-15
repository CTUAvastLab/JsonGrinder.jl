"""
	mutable struct MultiEntry <: JSONEntry
		childs::Vector{Any}
	end

	support for JSON which does not adhere to a fixed type. 
"""
mutable struct MultiEntry <: JSONEntry
	childs::Vector{Any}
	updated::Int
end

MultiEntry(s::MultiEntry) = s
MultiEntry(s::Vector{T}) where {T<:MultiEntry} = only(s)

Base.getindex(s::MultiEntry, k::Int) = s.childs[k]
Base.setindex!(s::MultiEntry, i, k::Int) = s.childs[k] = i
Base.isempty(e::MultiEntry) = isempty(e.childs)
Base.keys(e::MultiEntry) = collect(1:length(e.childs))


function update!(s::MultiEntry, d)
	s.updated += 1
	for c in s.childs
		update!(c, d) && return(true)
	end
	new_child = safe_update!(newentry(d), d)
	push!(s.childs, new_child)
	return(true)
end

suggestextractor(e::MultiEntry, settings = NamedTuple(); path = "") = MultipleRepresentation(map(i -> suggestextractor(i, settings; path = path),e.childs))

NodeType(::Type{T}) where T <: MultiEntry = InnerNode()
children(n::MultiEntry) = (; Dict( Symbol(1) => v for (k,v) in enumerate(n.childs))...)
childrenfields(::Type{T}) where T <: MultiEntry = (:childs)
noderepr(n::MultiEntry) = "[" * (isempty(n.childs) ? "Empty " : "") * "MultiEntry]"