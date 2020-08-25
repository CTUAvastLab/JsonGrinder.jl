
"""
	struct ExtractDict
		vec::Dict{String,Any}
		other::Dict{String,Any}
	end

	extracts all items in `vec` and in `other` and return them as a ProductNode.
"""
struct ExtractDict{S,V} <: AbstractExtractor
	vec::S
	other::V
	function ExtractDict(v::S,o::V) where {S<:Union{Dict,Nothing},V<:Union{Dict,Nothing}}
		v = (v == nothing || isempty(v)) ? nothing : v
		o = (o == nothing || isempty(o)) ? nothing : o
		new{typeof(v),typeof(o)}(v,o)
	end
end


function Base.getindex(m::ExtractDict, s::Symbol)
	m.vec != nothing && haskey(m.vec, s) && return(m.vec[s])
	m.other != nothing && haskey(m.other, s) && return(m.other[s])
	nothing
end

replacebyspaces(pad) = map(s -> (s[1], " "^length(s[2])), pad)

extractsmatrix(s::ExtractDict) = false
(s::ExtractDict)(v::V) where {V<:Nothing} = s(Dict{String,Any}())
(s::ExtractDict)(v)  = s(nothing)


function (s::ExtractDict{S,V})(v::Dict) where {S<:Dict,V<:Dict}
	x = vcat([f(get(v,String(k),nothing)) for (k,f) in s.vec]...)
	o = [Symbol(k) => f(get(v,String(k),nothing)) for (k,f) in s.other]
	data = (; :scalars => x,o...)
	ProductNode(data)
end

(s::ExtractDict{S,V})(v::Dict) where {S<:Dict,V<:Nothing} = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)

function (s::ExtractDict{S,V})(v::Dict) where {S<:Nothing,V<:Dict}
	o = [Symbol(k) => f(get(v,String(k),nothing)) for (k,f) in s.other]
	ProductNode((;o...))
end


extractbatch(extractor, samples) = reduce(catobs, map(s-> extractor(s), samples))

Base.hash(e::ExtractDict, h::UInt) = hash((e.vec, e.other), h)
Base.:(==)(e1::ExtractDict, e2::ExtractDict) = e1.vec == e2.vec && e1.other == e2.other
