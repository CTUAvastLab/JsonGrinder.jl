
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

extractsmatrix(s::ExtractBranch) = false
(s::ExtractBranch)(v::V) where {V<:Nothing} = s(Dict{String,Any}())

# function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
# 	x = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)
# 	o = [f(get(v,k,nothing)) for (k,f) in s.other]
# 	data = tuple(x, o...)
# 	ProductNode(data)
# end

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
	x = vcat([f(get(v,String(k),nothing)) for (k,f) in s.vec]...)
	o = [Symbol(k) => f(get(v,String(k),nothing)) for (k,f) in s.other]
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
