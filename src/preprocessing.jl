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
remove_nulls(V::AbstractVector) = [v for v in Iterators.map(remove_nulls, V) if !isnothing(v)]
function remove_nulls(d::T) where T <: AbstractDict
    res = Dict{String, valtype(d)}()
    for (k, v) in d
        v_res = remove_nulls(v)
        if !isnothing(v_res)
            res[string(k)] = v_res
        end
    end
    return res
end
