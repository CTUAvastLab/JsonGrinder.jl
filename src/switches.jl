const _max_values = Ref{Int}(@load_preference("max_values", 10_000))

"""
    JsonGrinder.max_values!(n::Int)

Get the current value of the `max_values` parameter.

See also: [`JsonGrinder.max_values!`](@ref).
"""
max_values() = _max_values[]

"""
    JsonGrinder.max_values!(n::Int; persist=false)

Set the value of the `max_values` parameter.

Set `persist=true` to persist this setting between sessions.

See also: [`JsonGrinder.max_values`](@ref).
"""
function max_values!(n::Int; persist=false)
    _max_values[] = n
    if persist
        @set_preferences!("max_values" => n)
    end
end

const _max_string_length = Ref{Int}(@load_preference("max_string_len", 10_000))

"""
    JsonGrinder.max_string_length!(n::Int)

Get the current value of the `max_string_length` parameter.

See also: [`JsonGrinder.max_string_length!`](@ref).
"""
max_string_length() = _max_string_length[]

"""
    JsonGrinder.max_string_length!(n::Int; persist=false)

Set the value of the `max_string_length` parameter.

Set `persist=true` to persist this setting between sessions.

See also: [`JsonGrinder.max_string_length`](@ref).
"""
function max_string_length!(n::Int; persist=false)
    _max_string_length[] = n
    if persist
        @set_preferences!("max_string_length" => n)
    end
end
