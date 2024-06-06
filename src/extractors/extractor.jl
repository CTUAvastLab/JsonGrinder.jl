#=
Why is it not possible to have fully type stable extraction?

using Test, JSON, JSON3

struct SimpleExtractor end
f(x) = Float32(x)
(::SimpleExtractor)(d) = (a = f(d.a), b = f(d.b))
e = SimpleExtractor()

js = """{"a": 1, "b": 2}"""
d1 = JSON.parse(js)
d2 = JSON3.read(js)
@inferred e(d1)
@inferred e(d2)

The only way out of this is to write our own type-stable parser using (frozen) schema.
=#

"""
    Extractor

Supertype for all extractor node types.
"""
abstract type Extractor end

"""
    LeafExtractor

Supertype for all leaf extractor node types that reside in the leafs of the hierarchy.
"""
abstract type LeafExtractor <: Extractor end

"""
    struct StableExtractor{T <: LeafExtractor} <: LeafExtractor

Wraps any other `LeafExtractor` and makes it output stable results w.r.t. missing input values.

See also: [`stabilizeextractor`](@ref).
"""
struct StableExtractor{T <: LeafExtractor} <: LeafExtractor
    e::T
end
Base.hash(e::StableExtractor, h::UInt) = hash((e.e,), h)
(e1::StableExtractor == e2::StableExtractor) = e1.e == e2.e

include("scalar.jl")
include("categorical.jl")
include("ngram.jl")
include("dict.jl")
include("array.jl")
include("polymorph.jl")

_missing_check(::Extractor) = _throw_missing()
_missing_check(::StableExtractor) = nothing

function (e::LeafExtractor)(v::Maybe; store_input=Val(false))
    ismissing(v) && _missing_check(e)
    ArrayNode(_extract_leaf(e, v), _metadata(v, store_input))
end
(e::LeafExtractor)(::Nothing) = ArrayNode(_extract_leaf(e, nothing))

_extract_leaf(_, _) = throw(IncompatibleExtractor())
_extract(_, _) = throw(IncompatibleExtractor())

_metadata(v, ::Val{true}) = [v]
_metadata(_, ::Val{false}) = nothing

function extract(e::LeafExtractor, V::AbstractVector; store_input=Val(false))
    ArrayNode(_extract_batch(e, V), _metadata_batch(V, store_input))
end
_metadata_batch(V, ::Val{true}) = isempty(V) ? nothing : V
_metadata_batch(_, ::Val{false}) = nothing

"""
    stabilizeextractor(e::Extractor)

Returns a new extractor with similar structure as `e`, containing `StableExtractor` in its leaves.

# Examples
```jldoctest
julia> e = (a=ScalarExtractor(), b=CategoricalExtractor(1:5)) |> DictExtractor
DictExtractor
  ├── a: ScalarExtractor(c=0.0, s=1.0)
  ╰── b: CategoricalExtractor(n=6)

julia> e_stable = stabilizeextractor(e)
DictExtractor
  ├── a: StableExtractor(ScalarExtractor(c=0.0, s=1.0))
  ╰── b: StableExtractor(CategoricalExtractor(n=6))

julia> e(Dict("a" => 0))
ERROR: IncompatibleExtractor at path [:b]: This extractor does not support missing values! See the `Stable Extractors` section in the docs.
[...]

julia> e_stable(Dict("a" => 0))
ProductNode  1 obs, 24 bytes
  ├── a: ArrayNode(1×1 Array with Union{Missing, Float32} elements)  1 obs, 53 bytes
  ╰── b: ArrayNode(6×1 MaybeHotMatrix with Union{Missing, Bool} elements)  1 obs, 77 bytes
```

See also: [`suggestextractor`](@ref), [`extract`](@ref).
"""
stabilizeextractor(e::StableExtractor) = e
stabilizeextractor(e::LeafExtractor) = StableExtractor(e)
stabilizeextractor(e::DictExtractor) = DictExtractor(map(stabilizeextractor, e.children))
stabilizeextractor(e::ArrayExtractor) = ArrayExtractor(stabilizeextractor(e.items))
stabilizeextractor(e::PolymorphExtractor) = PolymorphExtractor(map(stabilizeextractor, e.extractors))

"""
    suggestextractor(e::Schema; min_occurences=1, all_stable=false, categorical_limit=100)

given schema `e`, create a corresponding `Extractor`

- `min_occurences` specifies the minimum occurence of a key to be included in the extractor.
- `all_stable` makes all leaf extractors strictly stable.
- `categorical_limit` specifies the maximum number of different values in a leaf for it to be
    considered a categorical variable.
- `ngram_params` makes it possible to override default params for `NGramExtractor`.

# Examples
```jldoctest
julia> s = schema([ Dict("a" => 1, "b" => ["foo"], "c" => Dict("d" => 1)),
                    Dict("a" => 2,                 "c" => Dict())])
DictEntry 2x updated
  ├── a: LeafEntry (2 unique `Real` values) 2x updated
  ├── b: ArrayEntry 1x updated
  │        ╰── LeafEntry (1 unique `String` values) 1x updated
  ╰── c: DictEntry 2x updated
           ╰── d: LeafEntry (1 unique `Real` values) 1x updated

julia> suggestextractor(s)
DictExtractor
  ├── a: CategoricalExtractor(n=3)
  ├── b: ArrayExtractor
  │        ╰── StableExtractor(CategoricalExtractor(n=2))
  ╰── c: DictExtractor
           ╰── d: StableExtractor(CategoricalExtractor(n=2))

julia> suggestextractor(s; all_stable=true)
DictExtractor
  ├── a: StableExtractor(CategoricalExtractor(n=3))
  ├── b: ArrayExtractor
  │        ╰── StableExtractor(CategoricalExtractor(n=2))
  ╰── c: DictExtractor
           ╰── d: StableExtractor(CategoricalExtractor(n=2))

julia> suggestextractor(s; min_occurences=2)
DictExtractor
  ╰── a: CategoricalExtractor(n=3)

julia> suggestextractor(s; categorical_limit=0)
DictExtractor
  ├── a: ScalarExtractor(c=1.0, s=1.0)
  ├── b: ArrayExtractor
  │        ╰── StableExtractor(NGramExtractor(n=3, b=256, m=2053))
  ╰── c: DictExtractor
           ╰── d: StableExtractor(ScalarExtractor(c=1.0, s=1.0))
```

See also: [`extract`](@ref), [`stabilizeextractor`](@ref).
"""
function suggestextractor(e::Schema; min_occurences::Int=1, all_stable::Bool = false,
    categorical_limit::Int=100, ngram_params=NamedTuple())
    if categorical_limit > JsonGrinder.max_values()
        @warn "`categorical_limit` is higher than the result of `JsonGrinder.max_values(). " *
              "`CategoricalExtractor` will never be used." maxlog=1
    end
    _suggestextractor(e; all_stable, min_occurences, categorical_limit, ngram_params)
end

function _suggestextractor(e::LeafEntry{T}; all_stable, min_occurences,
    categorical_limit, ngram_params) where T
    e.updated ≥ min_occurences || return nothing
    if length(keys(e.counts)) ≤ categorical_limit
        res = CategoricalExtractor(e)
    elseif T <: Real
        res = ScalarExtractor(e)
    elseif T <: AbstractString
        res = NGramExtractor(; ngram_params...)
    else
        return nothing
    end
    all_stable ? StableExtractor(res) : res
end

function _suggestextractor(e::DictEntry; all_stable, min_occurences, kwargs...)
    e.updated ≥ min_occurences || return nothing
    children = map(collect(e.children)) do (k, ch)
        k => _suggestextractor(ch; all_stable=all_stable || e.updated > ch.updated, min_occurences, kwargs...)
    end
    filter!(!isnothing ∘ last, children)
    isempty(children) ? nothing : DictExtractor(NamedTuple(children))
end

function _suggestextractor(e::ArrayEntry; all_stable, min_occurences, kwargs...)
    e.updated ≥ min_occurences || return nothing
    isnothing(e.items) && return nothing
    # if length(e.lengths) == 1 && e.items isa LeafEntry{<:Real} && false
    #     return VectorizedExtractor(e)
    # end
    items = _suggestextractor(e.items; all_stable, min_occurences, kwargs...)
    isnothing(items) ? nothing : ArrayExtractor(items)
end

"""
    reflectinmodel(sch::Schema, ex::Extractor, args...; kwargs...)

Using schema `sch` and extractor `ex`, first create a representative sample and then call
`Mill.reflectinmodel`.
"""
function Mill.reflectinmodel(sch::Schema, ex::Extractor, args...; kwargs...)
    Mill.reflectinmodel(ex(representative_example(sch)), args...; kwargs...)
end

"""
    extract(e::Extractor, samples::AbstractVector; store_input=Val(false))

Efficient extraction of multiple samples at once.

Note that whereas `extract` expects `samples` to be a **vector** of samples
(as `schema` does), calling the extractor directly with `e(sample)` works for a
**single** sample. In other words, `e(sample)` is equivalent to `extract(e, [sample])`.

See also: [`suggestextractor`](@ref), [`stabilizeextractor`](@ref), [`schema`](@ref).

# Examples
```jldoctest
julia> sample = Dict("a" => 0, "b" => "foo");

julia> e = suggestextractor(schema([sample]))
DictExtractor
  ├── a: CategoricalExtractor(n=2)
  ╰── b: CategoricalExtractor(n=2)

julia> e(sample)
ProductNode  1 obs, 32 bytes
  ├── a: ArrayNode(2×1 OneHotArray with Bool elements)  1 obs, 76 bytes
  ╰── b: ArrayNode(2×1 OneHotArray with Bool elements)  1 obs, 76 bytes

julia> e(sample) == extract(e, [sample])
true
```
"""
function extract end
