
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


isfloat(s::AbstractString) = tryparse(Float64, s) isa Number
isint(s::AbstractString) = tryparse(Int64, s) isa Number

Entry(s::T) where {T<:Number} = Entry(Dict{Number,Int}(),0);
function Entry(s::T) where {T<:AbstractString} 
	# isint(s) && return(Entry(parse(Int, s)))
	# isfloat(s) && return(Entry(parse(Float64, s)))
	return(Entry(Dict{T,Int}(),0))
end

types(e::Entry) = unique(typeof.(collect(keys(e.counts))))
Base.keys(e::Entry) = sort(collect(keys(e.counts)))
Base.isempty(e::Entry) = false

unify_types(e::Entry) = promote_type(unique(typeof.(keys(e.counts)))...)

"""
		function update!(a::Entry, v)

		updates the entry when seeing value v
"""
update!(a::Entry{T}, v::Number) where {T<:Number} = _update!(a, v)
update!(a::Entry{T}, v::AbstractString) where {T<:AbstractString} = _update!(a, v)
function update!(a::Entry{T}, s::AbstractString) where {T<:Number} 
	isint(s) && return(_update!(a, parse(Int, s)))
	isfloat(s) && return(_update!(a, parse(Float64, s)))
	return(false)
end

function _update!(a::Entry, v)
	if length(keys(a.counts)) < max_keys
		a.counts[v] = get(a.counts,v,0) + 1
		# it's there because otherwise, after filling the count keys not even the existing ones are updates
	elseif haskey(a.counts, v)
		a.counts[v] += 1
	end
	a.updated +=1
	return(true)
end


function merge(es::Entry...)
	updates_merged = sum(map(x->x.updated, es))
	counts_merged = merge(+, map(x->x.counts, es)...)
	if length(counts_merged) > max_keys
		counts_merged_list = sort(collect(counts_merged), by=x->x[2], rev=true)
		counts_merged = Dict(counts_merged_list[1:max_keys])
	end
	Entry(counts_merged, updates_merged)
end

function suggestextractor(e::Entry, settings = NamedTuple(); path::String = "")
	t = unify_types(e::Entry)
	t == Any && @error "$(path): JSON does not have a fixed type scheme, quitting"

	for (c, ex) in get(settings, :scalar_extractors, default_scalar_extractor())
		c(e) && return ex(e)
	end
end

function default_scalar_extractor()
	[(e -> (length(keys(e.counts)) / e.updated < 0.1  && length(keys(e.counts)) <= 10000),
		e -> ExtractCategorical(collect(keys(e.counts)))),
	 (e -> unify_types(e) <: AbstractString && all(isint.(unique(keys(e.counts)))),
		e -> extractscalar(Int64, e)),
	 (e -> unify_types(e) <: AbstractString && all(isfloat.(unique(keys(e.counts)))),
	 	e -> extractscalar(Float64, e)),
	(e -> true,
		e -> extractscalar(unify_types(e), e)),]
end

Base.hash(e::Entry, h::UInt) = hash((e.counts, e.updated), h)
Base.:(==)(e1::Entry, e2::Entry) = e1.updated === e2.updated && e1.counts == e2.counts
sample_synthetic(e::Entry) = first(keys(e.counts))


NodeType(::Type{T}) where {T<:Entry} = LeafNode()
noderepr(n::Entry) = "[Scalar - $(join(sort(string.(types(n))), ","))], $(length(keys(n.counts))) unique values, updated = $(n.updated)"
