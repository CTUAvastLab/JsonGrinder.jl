abstract type Schema end

include("leaf.jl")
include("dict.jl")
include("array.jl")

"""
    update!(e, v)

updates the [`Schema`](@ref) `e` with value `v` and returns the resulting entry.
"""
function update!(e::Schema, v)
    throw(InconsistentSchema(String[], "Can't store `$(typeof(v))` into `$(typeof(e))`!"))
end

"""
    newentry(v)

    create and return a new [`Schema`](@ref) according to the type of `v` and insert `v` into it.
"""
function newentry(v)
    e = _newentry(v)
    update!(e, v)
    e
end
_newentry(::T) where T <: Union{AbstractString, Real} = LeafEntry(T)
_newentry(::AbstractDict) = DictEntry()
_newentry(::AbstractVector) = ArrayEntry()

"""
    schema([f=identity,] jsons)

Create schema from an array of `jsons` optionally mapped by function `f`.

See also: [`merge`](@ref), [`merge!`](@ref).
"""
schema(samples::AbstractArray) = schema(identity, samples)
function schema(f::Function, samples::AbstractArray)
    schema = newentry(f(samples[1]))
    for i in 2:length(samples)
        update!(schema, f(samples[i]))
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
