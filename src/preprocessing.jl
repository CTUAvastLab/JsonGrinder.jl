"""
    remove_nulls(js)

Return a new document in which all `null` values (represented as `nothing` in julia) are removed.

# Examples
```jldoctest
julia> remove_nulls(Dict("a" => 1, "b" => nothing))
Dict{String, Union{Nothing, Int64}} with 1 entry:
  "a" => 1

julia> [nothing, Dict("a" => 1), nothing, Dict("a" => nothing)] |> remove_nulls
2-element Vector{Dict{String}}:
 Dict("a" => 1)
 Dict{String, Nothing}()
```
"""
remove_nulls(x) = x
# In the future we might extend this so that JSON3 objects return also JSON3 objects,
# but given that the result will almost always be directly passed to `schema` or `extract`,
# there seems to be little added value.
remove_nulls(V::AbstractVector) = [v for v in Iterators.map(remove_nulls, V) if !isnothing(v)]
function remove_nulls(d::T) where T <: AbstractDict
    res = empty(d)
    for (k, v) in d
        v_res = remove_nulls(v)
        if !isnothing(v_res)
            res[k] = v_res
        end
    end
    return res
end
