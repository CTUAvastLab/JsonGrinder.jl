"""
    ScalarExtractor{T} <: Extractor

Extracts a numerical value, centered by subtracting `c` and scaled by `s`.
Strings are converted to numbers.

The extractor returns `ArrayNode{Matrix{Union{Missing, Int64}}, Nothing}` or it subtypes.
If passed `missing`, it extracts missing values which Mill understands and can work with.

The `extract_missing` field determines whether extractor may or may not accept `missing`.
If `extract_missing` is false, it does not accept missing values. If `extract_missing` is true, it accepts missing values,
and always returns Mill structure of type Union{Missing, T} due to type stability reasons.

It can be created also using `extractscalar(Float32, 5, 2)`

# Example
```jldoctest
julia> ScalarExtractor(Float32, 2, 3, true)(1)
1×1 ArrayNode{Matrix{Union{Missing, Float32}}, Nothing}:
 -3.0f0

julia> ScalarExtractor(Float32, 2, 3, true)(missing)
1×1 ArrayNode{Matrix{Union{Missing, Float32}}, Nothing}:
 missing

julia> ScalarExtractor(Float32, 2, 3, false)(1)
1×1 ArrayNode{Matrix{Float32}, Nothing}:
 -3.0
```
"""
struct ScalarExtractor <: LeafExtractor
    c::Float32
    s::Float32

    function ScalarExtractor(c::Number=0f0, s::Number=1f0)
        @assert s > 0 "`s` must be positive!"
        new(c, s)
    end
end

function ScalarExtractor(e::LeafEntry{<:Real})
    m, M = extrema(keys(e.counts))
    c = m
    s = 1.0 / (m == M ? 1.0 : (M - m))
    ScalarExtractor(c, s)
end

extract_leaf(e::ScalarExtractor, v::Real) = [e.s * (Float32(v) - e.c);;]
extract_leaf(::ScalarExtractor, ::Nothing) = Matrix{Float32}(undef, 1, 0)

function extract_leaf(e::StableExtractor{ScalarExtractor}, v::Real)
    convert(Matrix{Maybe{Float32}}, extract_leaf(e.e, v))
end
extract_leaf(::StableExtractor{ScalarExtractor}, ::Nothing) = Matrix{Maybe{Float32}}(undef, 1, 0)
extract_leaf(::StableExtractor{ScalarExtractor}, ::Missing) = Maybe{Float32}[missing;;]

# extract_leaf(e::ScalarExtractor, v::Real) = [e.s * (Float32(v) - e.c);;]
# function extract_leaf(e::StableExtractor{ScalarExtractor}, v::Real)
#     convert(Matrix{Maybe{Float32}}, extract_leaf(e.e, v))
# end

Base.hash(e::ScalarExtractor, h::UInt) = hash((e.c, e.s), h)
(e1::ScalarExtractor == e2::ScalarExtractor) = e1.c == e2.c && e1.s == e2.s
