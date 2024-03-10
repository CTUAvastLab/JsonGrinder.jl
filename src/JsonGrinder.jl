module JsonGrinder

using Accessors
using HierarchicalUtils
using JSON
using MacroTools
using Mill
using OneHotArrays
using Preferences
# using Printf
using SHA

import Base: merge, length
import Base: ==

const FloatType = Float32
const ScalarType = Union{AbstractString, Number}

include("switches.jl")

include("schema/schema.jl")
export schema, AbstractJSONEntry, LeafEntry, DictEntry, ArrayEntry

include("extractors/extractors.jl")
include("hierarchical_utils.jl")
# include("util.jl")
#
# export ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector, MultipleRepresentation, ExtractString, AuxiliaryExtractor, ExtractKeyAsField
# export suggestextractor, extractbatch, generate_html
#

function Base.show(io::IO, @nospecialize(n::Union{AbstractJSONEntry, AbstractExtractor}))
    print(io, nameof(typeof(n)))
    if !get(io, :compact, false)
        _show_details(io, n)
    end
end
_show_details(_, _) = nothing

function Base.show(io::IO, ::MIME"text/plain", @nospecialize(n::Union{AbstractJSONEntry, AbstractExtractor}))
    HierarchicalUtils.printtree(io, n; htrunc=5, vtrunc=10, breakline=false)
end

function Base.getindex(n::Union{AbstractJSONEntry, AbstractExtractor}, i::AbstractString)
    HierarchicalUtils.walk(n, i)
end

end # module
