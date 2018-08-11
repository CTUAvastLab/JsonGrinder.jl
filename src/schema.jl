using JSON

abstract type JSONEntry end;
StringOrNumber = Union{String,Number};
const max_keys = 1000

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
Base.show(io::IO, e::Entry,offset::Int=0) = paddedprint(io, @sprintf("[Scalar - %s], %d unique values, updated = %d",join(types(e)),length(keys(e.counts)),e.updated),0)
Base.keys(e::Entry) = sort(collect(keys(e.counts)))

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

function Base.show(io::IO, e::ArrayEntry,offset::Int=0) 
	paddedprint(io, "[Vector of\n",0);
	show(io,e.items,offset+2)
	paddedprint(io, @sprintf(" ], updated = %d ",e.updated),offset)
end

function update!(a::ArrayEntry,b::Vector)
	n = length(b)
	a.l[n] = get(a.l,n,0) + 1
	foreach(v -> update!(a.items,v),b)
	a.updated +=1
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

function Base.show(io::IO, e::DictEntry,offset::Int=0)
	paddedprint(io,"Dict\n",offset)
	for k in keys(e.childs)
			paddedprint(io,@sprintf("%s: ",k),offset+2);
	  	Base.show(io,e.childs[k],offset+4)
	  	print(io,"\n")
  end
end

function update!(s::DictEntry,d::Dict)
	s.updated +=1
	for (k,v) in d
		i = get(s.childs,k,newentry(v))
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
newentry(v::Vector) = ArrayEntry(newentry(v[1]))

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
		foreach(f -> update!(schema,JSON.parse(f)),a)
		schema
end


"""
		suggestextractor(T,e::DictEntry, mincount::Int = 0)

		create convertor of json to tree-structure of `DataNode`

		`T` type for numeric types
		`e` top-level of json hierarchy, typically returned by invoking schema
		`mincount` minimum occurrence of keys to be included into the extractor (default is zero)
"""
function suggestextractor(T,e::DictEntry, mincount::Int = 0)
	ks = Iterators.filter(k -> updated(e.childs[k]) > mincount, keys(e.childs))
	if isempty(ks)
		return(ExtractBranch(Dict{String,Any}(),Dict{String,Any}()))
	end
	c = map(k -> (k,suggestextractor(T, e.childs[k], mincount)),ks)
	mask = map(i -> typeof(i[2])<:ExtractScalar{T,S} where {T<:Number,S},c)
	mask = mask .| map(i -> typeof(i[2])<:ExtractCategorical,c)
	ExtractBranch(Dict(c[mask]),Dict(c[.! mask]))
end
updated(s::T) where {T<:JSONEntry} = s.updated
suggestextractor(T,e::Entry,mincount) = ExtractScalar(eltype(map(identity,keys(e.counts))))
suggestextractor(T,e::ArrayEntry,mincount) = ExtractArray(suggestextractor(T,e.items,mincount))
