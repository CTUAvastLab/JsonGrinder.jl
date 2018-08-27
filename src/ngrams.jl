"""
	ngrams!(o,x,n::Int,b::Int)

	store indexes of `n` grams of `x` with base `b` to `o`

"""
function ngrams!(o,x::T,n::Int,b::Int) where {T<:Union{Base.CodeUnits{UInt8,S} where S,Vector{I} where I<:Integer}}
	@assert b > maximum(x)
	@assert length(o) >= length(x) + n - 1
	idx = 0
	for (i,v) in enumerate(x) 
		idx = idx*b + v
		idx = (i>n) ? mod(idx,b^n) : idx 
		o[i] = idx
	end
	for i in 1:n-1
		idx = mod(idx,b^(n-i))
		o[length(x) + i] = idx
	end
	o
end

"""
	ngrams(x,n::Int,b::Int)

	indexes of `n` grams of `x` with base `b`

"""
ngrams(x::T,n::Int,b::Int) where {T<:Union{Base.CodeUnits{UInt8,S} where S,Vector{I} where I<:Integer}} = 	ngrams!(zeros(Int,length(x) + n - 1),x,n,b)
ngrams(x::T,n::Int,b::Int) where {T<:AbstractString} = ngrams(codeunits(x),n,b)

"""
	function countngrams!(o,x,n::Int,b::Int)

	counts number of of `n` grams of `x` with base `b` to `o` and store it to o

"""
function countngrams!(o,x::T,n::Int,b::Int) where {T<:Union{Base.CodeUnits{UInt8,S} where S,Vector{I} where I<:Integer}}
	@assert b > maximum(x)
	idx = 0
	for (i,v) in enumerate(x) 
		idx = idx*b + v
		idx = (i>n) ? mod(idx,b^n) : idx 
		o[mod(idx, length(o))+1] += 1
	end
	for i in 1:n-1
		idx = mod(idx,b^(n-i))
		o[mod(idx, length(o))+1] += 1
	end
	o
end

countngrams!(o,x::T,n::Int,b::Int) where {T<:AbstractString} = countngrams!(o,codeunits(x),n,b)

"""
	function countngrams(x,n::Int,b::Int)

	counts number of of `n` grams of `x` with base `b` to `o`

"""
countngrams(x,n::Int,b::Int,m) = countngrams!(zeros(Int,m),x,n,b)
function countngrams(x::Vector{T},n::Int,b::Int,m) where {T<:AbstractString}
	o = zeros(Int,m,length(x))
	for (i,s) in enumerate(x)
		countngrams!(view(o,:,i),x[i],n,b)
	end
	o
end


string2ngrams(x::T,n,m) where {T <: AbstractArray{I} where I<: AbstractString} = countngrams(Vector(x[:]),n,257,m)
string2ngrams(x::T,n,m) where {T<: AbstractString} = countngrams(x,n,257,m)
string2ngrams(x,n,m) = x
