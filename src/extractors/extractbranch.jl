
"""
	struct ExtractBranch
		vec::Dict{String,Any}
		other::Dict{String,Any}
	end

	extracts all items in `vec` and in `other` and return them as a TreeNode.
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


function Base.getindex(m::ExtractBranch, s::String)
	m.vec != nothing && haskey(m.vec, s) && return(m.vec[s])
	m.other != nothing && haskey(m.other, s) && return(m.other[s])
	nothing
end

replacebyspaces(pad) = map(s -> (s[1], " "^length(s[2])), pad)

function printdict(io, d::Dict, ml, c, pad, last::Bool = true)
	k = sort(collect(keys(d)))
  for i in 1:length(k)
  	p = (last && i == length(k)) ? "  └───" : "  ├───"
  	p*="─"^(ml-length(k[i]))
		show(io, d[k[i]], pad = vcat(replacebyspaces(pad), (c,p)) , key = " "*k[i])
  end
end

function Base.show(io::IO, m::ExtractBranch; pad = [], key::String="")
  c = COLORS[(length(pad)%length(COLORS))+1]
  ml = m.vec   != nothing ? maximum(length(k) for k in keys(m.vec)) : 0
  ml = m.other != nothing ? max(ml, maximum(length(k) for k in keys(m.other))) : ml
  key *=": "
  paddedprint(io,"$(key)struct\n", color = c, pad = pad)
	if m.vec != nothing
		printdict(io, m.vec, ml, c, pad, m.other == nothing)
	end
	if m.other != nothing
		printdict(io, m.other, ml, c, pad)
	end
end

extractsmatrix(s::ExtractBranch) = false
(s::ExtractBranch)(v::V) where {V<:Nothing} = s(Dict{String,Any}())


# function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
# 	x = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)
# 	o = [f(get(v,k,nothing)) for (k,f) in s.other]
# 	data = tuple(x, o...)
# 	TreeNode(data)
# end

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
	x = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)
	o = [Symbol(k) => f(get(v,k,nothing)) for (k,f) in s.other]
	# o = [f(get(v,k,nothing)) for (k,f) in s.other]
	data = (; :scalars => x,o...)
	# data = tuple(x, o...)
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
		return(TreeNode((;o...)))
	end
end


extractbatch(extractor, samples) = reduce(catobs, map(s-> extractor(s), samples))
