const _max_keys = Ref{Int}(@load_preference("max_keys", 10_000))

"""
    JsonGrinder.max_keys!(n::Int)

Get the current value of the `max_keys` parameter.

See also: [`JsonGrinder.max_keys!`](@ref).
"""
max_keys() = _max_keys[]

"""
    JsonGrinder.max_keys!(n::Int; persist=false)

Set the value of the `max_keys` parameter.

Set `persist=true` to persist this setting between sessions.

See also: [`JsonGrinder.max_keys`](@ref).
"""
function max_keys!(n::Int; persist=false)
    _max_keys[] = n
    if persist
        @set_preferences!("max_keys" => n)
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
