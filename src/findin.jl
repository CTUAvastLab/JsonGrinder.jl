using Setfield
import Mill.findin

function findin(x::T, node) where {T<:Union{AbstractExtractor, JSONEntry}}
    x === node && return @lens _
    for k in fieldnames(T)
        l = findin(getproperty(x, k), node)
        if l != nothing
            lo = Setfield.PropertyLens{k}() ∘ l
            return lo
        end
    end
    nothing
end

function findin(x::Dict{Symbol, <:Any}, node)
	x === node && return @lens _
    for k in keys(x)
    	l = findin(x[k], node)
    	if l != nothing
    		lo = Setfield.IndexLens(tuple(k)) ∘ l
    		return lo
    	end
    end
    nothing
end
