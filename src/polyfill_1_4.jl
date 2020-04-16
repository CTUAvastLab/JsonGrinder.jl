# copied from https://github.com/JuliaLang/julia/blob/v1.4.1/base/iterators.jl#L1269
using Base: @propagate_inbounds

"""
    only(x)
Returns the one and only element of collection `x`, and throws an `ArgumentError` if the
collection has zero or multiple elements.
See also: [`first`](@ref), [`last`](@ref).
"""
@propagate_inbounds function only(x)
    i = iterate(x)
    @boundscheck if i === nothing
        throw(ArgumentError("Collection is empty, must contain exactly 1 element"))
    end
    (ret, state) = i
    @boundscheck if iterate(x, state) !== nothing
        throw(ArgumentError("Collection has multiple elements, must contain exactly 1 element"))
    end
    return ret
end

# Collections of known size
only(x::Ref) = x[]
only(x::Number) = x
only(x::Char) = x
only(x::Tuple{Any}) = x[1]
only(x::Tuple) = throw(
    ArgumentError("Tuple contains $(length(x)) elements, must contain exactly 1 element")
)
only(a::AbstractArray{<:Any, 0}) = @inbounds return a[]
only(x::NamedTuple{<:Any, <:Tuple{Any}}) = first(x)
only(x::NamedTuple) = throw(
    ArgumentError("NamedTuple contains $(length(x)) elements, must contain exactly 1 element")
)
