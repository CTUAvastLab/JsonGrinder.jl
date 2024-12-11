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
remove_nulls(v::AbstractVector) = [x for x in Iterators.map(remove_nulls, v) if !isnothing(x)]
function remove_nulls(d::AbstractDict{T, U}) where {T <: Union{String, Symbol}, U}
    res = empty(d)
    for (k, v) in d
        v_res = remove_nulls(v)
        if !isnothing(v_res)
            res[k] = v_res
        end
    end
    return res
end

"""
    map_keys(f, d)

Return a new document in which all keys are (recursively) transformed by callable `f`.

# Examples
```jldoctest
julia> d = Dict("a" => 1, "b" => Dict("c" => "foo"))
Dict{String, Any} with 2 entries:
  "b" => Dict("c"=>"foo")
  "a" => 1

julia> map_keys(Symbol, d)
Dict{Symbol, Any} with 2 entries:
  :a => 1
  :b => Dict(:c=>"foo")

julia> map_keys(string, d)
Dict{String, Any} with 2 entries:
  "b" => Dict("c"=>"foo")
  "a" => 1
```
"""
map_keys(::Base.Callable, x) = x
map_keys(f::Function, d::AbstractDict) = Dict(f(k) => map_keys(f, v) for (k, v) in d)
function map_keys(T::Type, d::AbstractDict)
    if isempty(d)
        return Dict{T, Any}()
    else
        Dict(T(k) => map_keys(T, v) for (k, v) in d)
    end
end
