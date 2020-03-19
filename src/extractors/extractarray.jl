"""
	struct ExtractArray{T}
		item::T
	end

	convert array of values to one bag of values converted with `item`. Note that in order the function to work properly,
	calling `item` on a single item has to return Matrix.

```juliadoctest
julia> sc = ExtractArray(ExtractCategorical(Float32,2:4))
julia> sc([2,3,1,4]).data
3×4 Array{Float32,2}:
 1.0  0.0  0.0  0.0
 0.0  1.0  0.0  0.0
 0.0  0.0  0.0  1.0

```

```juliadoctest
julia> sc = ExtractArray(ExtractScalar())
julia> sc([2,3,4]).data
 2.0  3.0  4.0
```
"""
struct ExtractArray{T} <: AbstractExtractor
	item::T
end

extractsmatrix(s::ExtractArray) = false

function (s::ExtractArray)(v::V) where {V<:Union{Missing, Nothing}}
	ds = s.item(nothing)[1:0]
	BagNode(ds, [0:-1])
end

(s::ExtractArray)(v::V) where {V<:Vector} = isempty(v) ? s(nothing) : BagNode(reduce(catobs, map(s.item, v)),[1:length(v)])

function (s::ExtractArray)(v)
	@error "ExtractArray: unknown type $(typeof(v))"
	@show v
	BagNode(missing, [0:-1])
end
function Base.show(io::IO, m::ExtractArray; pad = [], key::String="")
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *= isempty(key) ? "" : ": "
	paddedprint(io,"$(key)Array of\n", color = c)
	paddedprint(io, "  └── ", color=c, pad=pad)
	show(io,m.item, pad = [pad; (c, "      ")])
end

Base.hash(e::ExtractArray, h::UInt) = hash(e.item, h)
Base.:(==)(e1::ExtractArray, e2::ExtractArray) = e1.item == e2.item
