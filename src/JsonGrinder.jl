module JsonGrinder

using Accessors
using Compat
using HierarchicalUtils
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
@compat public max_values, max_values!
@compat public max_string_codeunits, max_string_codeunits!

include("exceptions.jl")

include("schema/schema.jl")
export schema, update!, newentry, Schema, LeafEntry, DictEntry, ArrayEntry

include("extractors/extractor.jl")
export Extractor, DictExtractor, ArrayExtractor, PolymorphExtractor
export LeafExtractor, ScalarExtractor, CategoricalExtractor, NGramExtractor, StableExtractor
export suggestextractor, stabilizeextractor, extract

include("preprocessing.jl")
export remove_nulls, map_keys

include("util.jl")
export pred_lens, list_lens, find_lens, findnonempty_lens
export replacein, code2lens, lens2code

function Base.getindex(n::Union{Schema, Extractor}, i::AbstractString)
    HierarchicalUtils.walk(n, i)
end

include("show.jl")
export printtree

end
