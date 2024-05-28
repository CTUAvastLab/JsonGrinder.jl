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

abstract type Extractor end
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

_missing_check(::Extractor) = error("This extractor does not support missing values!")
_missing_check(::StableExtractor) = nothing

function (e::LeafExtractor)(v::Maybe; store_input=Val(false))
    ismissing(v) && _missing_check(e)
    ArrayNode(extract_leaf(e, v), _metadata(v, store_input))
end
(e::LeafExtractor)(::Nothing) = ArrayNode(extract_leaf(e, nothing))

_metadata(v, ::Val{true}) = [v]
_metadata(_, ::Val{false}) = nothing

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
ERROR: This extractor does not support missing values!
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
    if categorical_limit > JsonGrinder.max_keys()
        @warn "`categorical_limit` is higher than the result of `JsonGrinder.max_keys(). " *
              "`CategoricalExtractor` will never be used." maxlog=1
    end
    _suggestextractor(e, all_stable, min_occurences, categorical_limit, ngram_params)
end

function _suggestextractor(e::LeafEntry{T}, stable, mo, cl, ngp) where T
    e.updated ≥ mo || return nothing
    if length(keys(e.counts)) ≤ cl
        res = CategoricalExtractor(e)
    elseif T <: Real
        res = ScalarExtractor(e)
    elseif T <: AbstractString
        res = NGramExtractor(; ngp...)
    else
        return nothing
    end
    stable ? StableExtractor(res) : res
end

function _suggestextractor(e::DictEntry, stable::Bool, mo, cl, ngp)
    e.updated ≥ mo || return nothing
    children = map(collect(e.children)) do (k, ch)
        k => _suggestextractor(ch, stable || e.updated > ch.updated, mo, cl, ngp)
    end
    filter!(!isnothing ∘ last, children)
    isempty(children) ? nothing : DictExtractor(NamedTuple(children))
end

function _suggestextractor(e::ArrayEntry, stable::Bool, mo, cl, ngp)
    e.updated ≥ mo || return nothing
    isnothing(e.items) && return nothing
    # if length(e.lengths) == 1 && e.items isa LeafEntry{<:Real} && false
    #     return VectorizedExtractor(e)
    # end
    items = _suggestextractor(e.items, stable, mo, cl, ngp)
    isnothing(items) ? nothing : ArrayExtractor(items)
end

function Mill.reflectinmodel(sch::Schema, ex::Extractor, args...; kwargs...)
    Mill.reflectinmodel(ex(representative_example(sch)), args...; kwargs...)
end

# TODO batch extraction
# comment behavior on samples
"""
	extract(extractor, samples)

utility function, shortcut for mapreduce(extractor, catobs, samples)

See also: [`suggestextractor`](@ref), [`stabilizeextractor`](@ref).
"""
extract(extractor, samples) = mapreduce(extractor, catobs, samples)

