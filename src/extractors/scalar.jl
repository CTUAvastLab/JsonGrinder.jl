"""
    ScalarExtractor{T} <: Extractor

Extracts a numerical value, centered by subtracting `c` and scaled by `s`.

# Examples
```jldoctest
julia> e = ScalarExtractor(2, 3)
ScalarExtractor(c=2.0, s=3.0)

julia> e(0)
1×1 ArrayNode{Matrix{Float32}, Nothing}:
 -6.0

julia> e(1)
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

_extract_leaf(e::ScalarExtractor, v::Real) = [e.s * (Float32(v) - e.c);;]
_extract_leaf(::ScalarExtractor, ::ExtractEmpty) = Matrix{Float32}(undef, 1, 0)

function _extract_leaf(e::StableExtractor{ScalarExtractor}, v::Real)
    convert(Matrix{Maybe{Float32}}, _extract_leaf(e.e, v))
end
_extract_leaf(::StableExtractor{ScalarExtractor}, ::ExtractEmpty) = Matrix{Maybe{Float32}}(undef, 1, 0)
_extract_leaf(::StableExtractor{ScalarExtractor}, ::Missing) = Maybe{Float32}[missing;;]

_extract_value(e::ScalarExtractor, v::Real) = e.s * (Float32(v) - e.c)
_extract_value(::ScalarExtractor, ::Missing) = _error_missing()
_extract_value(::ScalarExtractor, ::Nothing) = _error_null_values()

function _extract_batch(e::ScalarExtractor, V)
    M = Matrix{Float32}(undef, 1, length(V))
    @inbounds for (i, v) in enumerate(V)
        M[1, i] = _extract_value(e, v)
    end
    M
end

_extract_value(e::StableExtractor{ScalarExtractor}, v::Real) = _extract_value(e.e, v)
_extract_value(::StableExtractor{ScalarExtractor}, ::Missing) = missing
_extract_value(::StableExtractor{ScalarExtractor}, ::Nothing) = _error_null_values()

function _extract_batch(e::StableExtractor{ScalarExtractor}, V)
    M = Matrix{Maybe{Float32}}(undef, 1, length(V))
    @inbounds for (i, v) in enumerate(V)
        M[1, i] = _extract_value(e, v)
    end
    M
end

Base.hash(e::ScalarExtractor, h::UInt) = hash((e.c, e.s), h)
(e1::ScalarExtractor == e2::ScalarExtractor) = e1.c == e2.c && e1.s == e2.s
