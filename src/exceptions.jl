abstract type JSONGrinderException <: Exception end

struct InconsistentSchema{T <: AbstractString, U <: AbstractString} <: JSONGrinderException
    path::Vector{T}
    msg::U
end

struct IncompatibleExtractor{T <: AbstractString, U <: AbstractString} <: JSONGrinderException
    path::Vector{T}
    msg::U
end

InconsistentSchema(msg::AbstractString="") = InconsistentSchema(String[], msg)
IncompatibleExtractor(msg::AbstractString="") = IncompatibleExtractor(String[], msg)

function _throw_missing()
    throw(IncompatibleExtractor("This extractor does not support missing values! " *
        "See the `Stable Extractors` section in the docs."))
end

function Base.showerror(io::IO, ex::T) where T <: JSONGrinderException
    Base.print(io, nameof(T), " at ")
    Base.print(io, isempty(ex.path) ? "root" : "path " * prod(reverse(ex.path)), ": ")
    Base.print(io, ex.msg)
end

macro try_catch_array(ex)
    quote
        try
            $(esc(ex))
        catch e
            if e isa JSONGrinderException
                push!(e.path, "[]")
            end
            rethrow(e)
        end
    end
end

macro try_catch_dict(k, ex)
    quote
        try
            $(esc(ex))
        catch e
            if e isa JSONGrinderException
                push!(e.path, "[:" * string($(esc(k))) * "]")
            end
            rethrow(e)
        end
    end
end
