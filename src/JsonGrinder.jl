module JsonGrinder

using Accessors
using HierarchicalUtils
using JSON
using MacroTools
using Mill
using OneHotArrays
using Preferences
using SHA

using Mill: Maybe, Optional
using Accessors: PropertyLens, IndexLens

import Base: ==

const FloatType = Float32

include("switches.jl")

include("exceptions.jl")

include("schema/schema.jl")
export schema, Schema, LeafEntry, DictEntry, ArrayEntry

include("extractors/extractor.jl")
export Extractor, ArrayExtractor, DictExtractor, PolymorphExtractor
export LeafExtractor, ScalarExtractor, CategoricalExtractor, NGramExtractor, StableExtractor
export extract, suggestextractor, stabilizeextractor

include("util.jl")

function Base.getindex(n::Union{Schema, Extractor}, i::AbstractString)
    HierarchicalUtils.walk(n, i)
end

include("show.jl")
export printtree

end
