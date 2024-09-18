module JsonGrinder

using Accessors
using HierarchicalUtils
using MacroTools
using Mill
using OneHotArrays
using Preferences
using SHA

using Mill: Maybe, Optional
using Accessors: PropertyLens, IndexLens

import Base: ==
import Base.Iterators: peel, map as imap

const FloatType = Float32

include("switches.jl")

include("exceptions.jl")

include("schema/schema.jl")
export schema, update!, newentry, Schema, LeafEntry, DictEntry, ArrayEntry

include("extractors/extractor.jl")
export Extractor, DictExtractor, ArrayExtractor, PolymorphExtractor
export LeafExtractor, ScalarExtractor, CategoricalExtractor, NGramExtractor, StableExtractor
export suggestextractor, stabilizeextractor, extract

include("util.jl")
export pred_lens, list_lens, find_lens, findnonempty_lens
export replacein, code2lens, lens2code

function Base.getindex(n::Union{Schema, Extractor}, i::AbstractString)
    HierarchicalUtils.walk(n, i)
end

include("show.jl")
export printtree

end
