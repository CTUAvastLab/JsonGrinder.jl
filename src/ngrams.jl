function ngrams!(o::Vector{Int},x::Vector{Int},n::Int,b::Int)
	assert(b > maximum(x))
	assert(length(o) >= length(x) + n - 1)
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

ngrams(x::Vector{Int},n::Int,b::Int) = 	ngrams!(zeros(Int,length(x) + n - 1),x,n,b)
