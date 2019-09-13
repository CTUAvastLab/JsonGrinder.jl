using Mill: ArrayNode, BagNode, TreeNode, catobs
abstract type AbstractReflector end;
"""
	struct ExtractScalar{T}
		datatype::Type{T}
		c::T
		s::T
	end

	extract a scalar value and center. If `T` is of type number, it is centered by first subtracting c and then
	multiplying that with s. 
"""
struct ExtractScalar{T<:Number,V} <: AbstractReflector
	datatype::Type{T}
	c::V
	s::V
end

extractsmatrix(s::ExtractScalar) = true
dimension(s::ExtractScalar) = 1
(s::ExtractScalar{T,V})(v) where {T<:Number,V}			 = ArrayNode(s.s .* (fill(s.datatype(v),1,1) .- s.c))
(s::ExtractScalar{T,V} where {V,T<:Number})(v::String)   = s((parse(s.datatype,v)))
(s::ExtractScalar{T,V})(v::S) where {T<:Number,V,S<:Nothing}= ArrayNode(fill(zero(T),(1,1)))
function Base.show(io::IO, m::ExtractScalar;pad = [], key::String="") 
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "; 
	paddedprint(io,"$(key)$(m.datatype)\n", color = c, pad = pad)
end


struct ExtractString{T} <: AbstractReflector
	datatype::Type{T}
	n::Int
	b::Int
	m::Int
end

ExtractString(::Type{T}) where {T<:String} = ExtractString(T, 3, 256, 2053)
(s::ExtractString)(v)   = ArrayNode(Mill.NGramMatrix([v], s.n, s.b, s.m))
(s::ExtractString)(v::S) where {S<:Nothing}= ArrayNode(Mill.NGramMatrix([""], s.n, s.b, s.m))
extractsmatrix(s::ExtractString) = false
dimension(s::ExtractString) = s.m
function Base.show(io::IO, m::ExtractString;pad = [], key::String="") 
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "; 
	paddedprint(io,"$(key)$(m.datatype)\n", color = c, pad = pad)
end


"""
	extractscalar(Type{String}, n = 3, b = 256, m = 2053)

	represents strings as ngrams with 
		--- `n` (the degree of ngram), 
		--- `b` base of string, 
		--- `m` modulo on index of the token to reduce dimension

	extractscalar(Type{Number}, m = 0, s = 1)
	extracts number subtracting `m` and multiplying by `s`
"""
extractscalar(::Type{T}, n = 3, b = 256, m = 2053) where {T<:AbstractString} = ExtractString(T, n, b, m)
extractscalar(::Type{T}, m = zero(T), s = one(T)) where {T<:Number} = ExtractScalar(T, m, s)


"""
	struct ExtractCategorical{T}
		datatype::Type{T}
		items::T
	end

	Convert scalar to one-hot encoded array.
"""
struct ExtractCategorical{T,I<:Vector} <: AbstractReflector
	datatype::Type{T}
	items::I
end

extractsmatrix(s::ExtractCategorical) = true
ExtractCategorical(items) = ExtractCategorical(Float32,items)
ExtractCategorical(T,s::Entry) = ExtractCategorical(T,sort(collect(keys(s.counts))))
ExtractCategorical(T,s::UnitRange) = ExtractCategorical(T,collect(s))
dimension(s::ExtractCategorical)  = dimension(s.items)
function (s::ExtractCategorical)(v) 
	x = zeros(s.datatype,length(s.items), 1)
	i = findfirst(isequal(v),s.items)
	if i != nothing
		x[i] = 1
	end
	ArrayNode(x)
end

(s::ExtractCategorical)(v::V) where {V<:Nothing} =  ArrayNode(zeros(s.datatype,length(s.items), 1))
function Base.show(io::IO, m::ExtractCategorical;pad = [], key::String="") 
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "; 
	paddedprint(io,"$(key)Categorical\n", color = c, pad = pad)
end

"""
	struct ExtractArray{T}
		item::T
	end

	convert array of values to one bag of values converted with `item`. Note that in order the function to work properly,
	calling `item` on a single item has to return Matrix.

```juliadoctest
julia> sc = ExtractArray(ExtractCategorical(Float32,2:4))
julia> sc([2,3,1,4]).data
3×4 Array{Float32,2}:
 1.0  0.0  0.0  0.0
 0.0  1.0  0.0  0.0
 0.0  0.0  0.0  1.0

```

```juliadoctest
julia> sc = ExtractArray(ExtractScalar())
julia> sc([2,3,4]).data
 2.0  3.0  4.0
```
"""
struct ExtractArray{T} <: AbstractReflector
	item::T
end

extractsmatrix(s::ExtractArray) = false
dimension(s::ExtractArray)  = dimension(s.item)
(s::ExtractArray)(v::V) where {V<:Nothing} = BagNode(reduce(catobs, s.item.([nothing])),[1:1])
(s::ExtractArray)(v) = isempty(v) ? s(nothing) : BagNode(reduce(catobs, s.item.(v)),[1:length(v)])

function Base.show(io::IO, m::ExtractArray; pad = [], key::String="")
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "
	paddedprint(io,"$(key)Array of \n", color = c, pad = pad)
	show(io,m.item, pad = vcat(replacebyspaces(pad), (c, "  └──")))
end

"""
	struct ExtractBranch
		vec::Dict{String,Any}
		other::Dict{String,Any}
	end

	extracts all items in `vec` and in `other` and return them as a TreeNode.
"""
struct ExtractBranch{S,V} <: AbstractReflector
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


function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
	x = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)
	o = [Symbol(k) => f(get(v,k,nothing)) for (k,f) in s.other]
	data = (; :scalar => x,o...)
	TreeNode(data)
end

(s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Nothing} = vcat([f(get(v,k,nothing)) for (k,f) in s.vec]...)

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Nothing,V<:Dict}
	o = [Symbol(k) => f(get(v,k,nothing)) for (k,f) in s.other]
	if length(o) == 1
		return(o[1].second)
	else 
		return(TreeNode((;o...)))
	end
end


extractbatch(extractor, samples) = reduce(catobs, map(s-> extractor(s), samples))
