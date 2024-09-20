"""
    Schema

Supertype for all schema node types.
"""
abstract type Schema end

include("leaf.jl")
include("dict.jl")
include("array.jl")

"""
    update!(e, v)

Update the [`Schema`](@ref) `e` with value `v` and return the resulting entry.
"""
function update!(e::Schema, v)
    throw(InconsistentSchema(String[], "Can't store `$(typeof(v))` into `$(typeof(e))`!"))
end
update!(::Schema, ::Nothing) = _error_null_values()

"""
    newentry(v)

Create and return a new [`Schema`](@ref) according to the type of `v`.
"""
newentry(::T) where T <: Union{AbstractString, Real} = LeafEntry(T)
newentry(::AbstractDict) = DictEntry()
newentry(::AbstractVector) = ArrayEntry()
newentry(::Nothing) = _error_null_values()
newentry(::T) where T = throw(InconsistentSchema("Unexpected `$T` in the document."))

"""
    schema([f=identity,] jsons)

Create schema from an iterable of `jsons` optionally mapped by function `f`.

See also: [`merge`](@ref), [`merge!`](@ref).
"""
schema(samples) = schema(identity, samples)
function schema(f::Function, samples)
    mapped = Iterators.map(f, samples)
    schema = newentry(first(mapped))
    for s in mapped
        update!(schema, s)
    end
    schema
end

"""
    merge!(schema, others...)

Merge multiple schemas `others` into `schema` inplace.

See also: [`merge`](@ref), [`schema`](@ref).
"""
function Base.merge!(::T, others::Schema...) where T <: Schema
    types = join('`' .* string.(typeof.(others)) .* '`', ", ", " and ")
    msg = "Can't merge the types $types into `$T`!"
    throw(InconsistentSchema(String[], msg))
end

"""
    merge(schemas...)

Merge multiple schemas into one.

Useful when for example distributing calculation of schema across multiple workers to aggregate
all results.

See also: [`merge!`](@ref), [`schema`](@ref).
"""
Base.merge(schemas::Schema...) = reduce(merge, collect(schemas))

function Base.reduce(::typeof(merge), schemas::Vector{<:Schema})
    types = join('`' .* string.(typeof.(schemas)) .* '`', ", ", " and ")
    msg = "Can't merge the types $(types)!"
    throw(InconsistentSchema(String[], msg))
end
