
"""
	struct ExtractDict
		dict::Dict{Symbol,Any}
	end

	extracts all items in `vec` and in `other` and return them as a ProductNode.
"""
struct ExtractDict{S} <: AbstractExtractor
	dict::S
	function ExtractDict(d::S) where {S<:Union{Dict,Nothing}}
		d = (isnothing(d) || isempty(d)) ? nothing : d
		new{typeof(d)}(d)
	end
end


function Base.getindex(m::ExtractDict, s::Symbol)
	!isnothing(m.dict) && haskey(m.dict, s) && return m.dict[s]
	nothing
end

replacebyspaces(pad) = map(s -> (s[1], " "^length(s[2])), pad)
# todo: dodělat missingy, všchny nothing předělat na missing a pořádně to otestovat
extractsmatrix(s::ExtractDict) = false
(s::ExtractDict)(v::V) where {V<:Nothing} = s(Dict{String,Any}())
(s::ExtractDict)(v)  = s(nothing)


function (s::ExtractDict{S})(v::Dict) where {S<:Dict}
	o = [Symbol(k) => f(get(v,String(k),nothing)) for (k,f) in s.dict]
	ProductNode((; o...))
end

extractbatch(extractor, samples) = reduce(catobs, map(s-> extractor(s), samples))

Base.hash(e::ExtractDict, h::UInt) = hash(e.dict, h)
Base.:(==)(e1::ExtractDict, e2::ExtractDict) = e1.dict == e2.dict
