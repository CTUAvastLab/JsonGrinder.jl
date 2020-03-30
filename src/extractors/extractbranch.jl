
"""
	struct ExtractBranch
		vec::Dict{String,Any}
		other::Dict{String,Any}
	end

	extracts all items in `vec` and in `other` and return them as a ProductNode.
"""
struct ExtractBranch{S,V} <: AbstractExtractor
	vec::S
	other::V
	function ExtractBranch(v::S,o::V) where {S<:Union{Dict,Nothing},V<:Union{Dict,Nothing}}
		v = (v == nothing || isempty(v)) ? nothing : v
		o = (o == nothing || isempty(o)) ? nothing : o
		new{typeof(v),typeof(o)}(v,o)
	end
end


function Base.getindex(m::ExtractBranch, s::Symbol)
	m.vec != nothing && haskey(m.vec, s) && return(m.vec[s])
	m.other != nothing && haskey(m.other, s) && return(m.other[s])
	nothing
end

replacebyspaces(pad) = map(s -> (s[1], " "^length(s[2])), pad)
#
# function printdict(io, d::Dict, ml, c, pad)
#   k = sort(collect(keys(d)))
#   for i in 1:length(k)-1
# 	  s = "  ├──"*"─"^(ml-length(k[i]))*" "
# 		  paddedprint(io, s, color=c, pad=pad)
# 		  show(io, d[k[i]], pad=[pad; (c, "  │"*" "^(ml-length(k[i])+2))], key = string(k[i]))
#   end
#   s = "  └──"*"─"^(ml-length(k[end]))*" "
#   paddedprint(io, s, color=c, pad=pad)
#   show(io, d[k[end]], pad=[pad; (c, " "^(ml-length(string(k[end]))+4))], key = string(k[end]))
# end

#
# function Base.show(io::IO, m::ExtractBranch; pad = [], key::String="")
#   c = COLORS[(length(pad)%length(COLORS))+1]
#   ml = m.vec   != nothing ? maximum(length(k) for k in keys(m.vec)) : 0
#   ml = m.other != nothing ? max(ml, maximum(length(k) for k in keys(m.other))) : ml
#   key *=": "
#   paddedprint(io,"$(key)struct\n", color = c)
# 	if isnothing(m.vec)
# 		paddedprint(io, "  Empty vec\n", color = c, pad=pad)
# 	else
# 		paddedprint(io, "  Vec:\n", color = c, pad=pad)
# 		printdict(io, m.vec, ml, c, pad)
# 	end
# 	if isnothing(m.other)
# 		paddedprint(io, "  Empty other\n", color = c, pad=pad)
# 	else
# 		paddedprint(io, "  Other:\n", color = c, pad=pad)
# 		printdict(io, m.other, ml, c, pad)
# 	end
# end

extractsmatrix(s::ExtractBranch) = false
(s::ExtractBranch)(v::V) where {V<:Nothing} = s(Dict{String,Any}())

# function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
# 	x = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)
# 	o = [f(get(v,k,nothing)) for (k,f) in s.other]
# 	data = tuple(x, o...)
# 	ProductNode(data)
# end

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
	x = vcat([f(get(v,string(k),nothing)) for (k,f) in s.vec]...)
	o = [Symbol(k) => f(get(v,string(k),nothing)) for (k,f) in s.other]
	data = (; :scalars => x,o...)
	TreeNode(data)
end

(s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Nothing} = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Nothing,V<:Dict}
	# o = [f(get(v,k,nothing)) for (k,f) in s.other]
	o = [Symbol(k) => f(get(v,k,nothing)) for (k,f) in s.other]
	if length(o) == 1
		# return(o[1])
		return(o[1].second)
	else
		return(ProductNode((;o...)))
	end
end


extractbatch(extractor, samples) = reduce(catobs, map(s-> extractor(s), samples))

Base.hash(e::ExtractBranch, h::UInt) = hash((e.vec, e.other), h)
Base.:(==)(e1::ExtractBranch, e2::ExtractBranch) = e1.vec == e2.vec && e1.other == e2.other
