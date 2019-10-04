using JSON

abstract type JSONEntry end;
StringOrNumber = Union{String,Number};
max_keys = 10000

function updatemaxkeys!(n::Int)
	global max_keys = n 
end

"""
	mutable struct Entry <: JSONEntry
		counts::Dict{Any,Int}
		updated::Int
	end

	Keeps statistics about scalar values of a one key
	`count` counts how many times given value appeared (at most max_keys is held)
	`updated` counts how many times the entry was updated
"""
mutable struct Entry <: JSONEntry
	counts::Dict{Any,Int}
	updated::Int
end

Entry() = Entry(Dict{Any,Int}(),0);
types(e::Entry) = unique(typeof.(collect(keys(e.counts))))
Base.keys(e::Entry) = sort(collect(keys(e.counts)))
function Base.show(io::IO, e::Entry;pad =[], key = "") 
	key *= isempty(key) ? ""  : ": "
	paddedprint(io, @sprintf("%s[Scalar - %s], %d unique values, updated = %d\n",key,join(types(e)),length(keys(e.counts)),e.updated))
end

function suggestextractor(T,e::Entry, mincount, category_rate::Float64 = 0.1, category_level::Int = 100) 
	if length(keys(e.counts)) / e.updated < category_rate  && length(keys(e.counts)) <= category_level
		return(ExtractCategorical(collect(keys(e.counts))))
	else 
		return(extractscalar(eltype([k for k in keys(e.counts)])))
	end
end
"""
		function update!(a::Entry,v)

		updates the entry when seeing value v
"""	
function update!(a::Entry,v)
	if length(keys(a.counts)) < max_keys
		a.counts[v] = get(a.counts,v,0) + 1
	end
	a.updated +=1
end


"""
		mutable struct ArrayEntry{A<:JSONEntry} <: JSONEntry
			items::A
			l::Dict{Int,Int}
			updated::Int
		end

		keeps statistics about an array entry in JSON. 
		`items` is typeof `Entry` and keeps statistics about the elements of the array
		`l` keeps histogram of message length 
		`updated` counts how many times the struct was updated.
"""
mutable struct ArrayEntry{A<:JSONEntry} <: JSONEntry
	items::A
	l::Dict{Int,Int}
	updated::Int
end

ArrayEntry(items) = ArrayEntry(items,Dict{Int,Int}(),0)

function Base.show(io::IO, e::ArrayEntry; pad = [], key = "") 
  c = COLORS[(length(pad)%length(COLORS))+1]
  # paddedprint(io,"Vector with $(length(e.items)) items(s). (updated = $(e.updated))\n", color=c)
  paddedprint(io,"$(key): [List] (updated = $(e.updated))\n", color=c)
  paddedprint(io, "  └── ", color=c, pad=pad)
  show(io, e.items, pad = [pad; (c, "      ")])
end

function update!(a::ArrayEntry,b::Vector)
	n = length(b)
	a.l[n] = get(a.l,n,0) + 1
	foreach(v -> update!(a.items,v),b)
	a.updated +=1
end

function suggestextractor(T, node::ArrayEntry, mincount::Int = 0, category_rate::Float64 = 0.1, category_level::Int = 100) 
	e = suggestextractor(T,node.items,mincount)
	isnothing(e) ? e : ExtractArray(e)
end


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
	childs::Dict{String,Any}
	updated::Int
end

DictEntry() = DictEntry(Dict{String,Any}(),0)
Base.getindex(s::DictEntry,k) = s.childs[k]

function Base.show(io::IO, e::DictEntry; pad=[], key = "")
    c = COLORS[(length(pad)%length(COLORS))+1]
    k = sort(collect(keys(e.childs)))
    if isempty(k) 
    	paddedprint(io, "$(key)[Empty Dict]\n", color=c)	
    	return
    end
    ml = maximum(length.(k))
    key *= ": "
	  paddedprint(io, "$(key)[Dict]\n", color=c)

    for i in 1:length(k)-1
    	s = "  ├──"*"─"^(ml-length(k[i]))*" "
			paddedprint(io, s, color=c, pad=pad)
			show(io, e.childs[k[i]], pad=[pad; (c, "  │"*" "^(ml-length(k[i])+2))], key = k[i])
    end
    s = "  └──"*"─"^(ml-length(k[end]))*" "
    paddedprint(io, s, color=c, pad=pad)
    show(io, e.childs[k[end]], pad=[pad; (c, " "^(ml-length(k[end])+4))], key = k[end])
end

function update!(s::DictEntry,d::Dict)
	s.updated +=1
	for (k,v) in d
		v == nothing && continue
		i = get(s.childs,k,newentry(v))
		i == nothing && continue
		update!(i,v)
		s.childs[k] = i
	end
end

"""
		newentry(v)

		creates new entry describing json according to the type of v
"""
newentry(v::Dict) = DictEntry()
newentry(v::A) where {A<:StringOrNumber} = Entry()
newentry(v::Vector) = isempty(v) ? nothing : ArrayEntry(newentry(v[1]))

"""
		function schema(a::Vector{T}) where {T<:Dict}
		function schema(a::Vector{T}) where {T<:AbstractString}
	
		create schema from an array of parsed or unparsed JSONs
"""
function schema(a::Vector{T}) where {T<:Dict}
	schema = DictEntry()
	foreach(f -> update!(schema,f),a)
	schema
end

function schema(a::Vector{T}) where {T<:AbstractString}
	schema = DictEntry()
	foreach(f -> update!(schema,JSON.parse(f)), a)
	schema
end


"""
		suggestextractor(T,e::DictEntry, mincount::Int = 0)

		create convertor of json to tree-structure of `DataNode`

		`T` type for numeric types
		`e` top-level of json hierarchy, typically returned by invoking schema
		`mincount` minimum occurrence of keys to be included into the extractor (default is zero)
"""
function suggestextractor(T, e::DictEntry, mincount::Int = 0, category_rate::Float64 = 0.1, category_level::Int = 100)
	ks = Iterators.filter(k -> updated(e.childs[k]) > mincount, keys(e.childs))
	isempty(ks) && return(nothing)
	c = [(k,suggestextractor(T, e.childs[k], mincount)) for k in ks]
	c = filter(s -> s[2] != nothing, c)
	isempty(c) && return(nothing)
	mask = map(i -> extractsmatrix(i[2]), c)
	ExtractBranch(Dict(c[mask]),Dict(c[.! mask]))
end
updated(s::T) where {T<:JSONEntry} = s.updated
