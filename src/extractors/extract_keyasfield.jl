
"""
	struct ExtractKeyAsField{S,V} <: AbstractExtractor
		key::S
		item::V
	end

	extracts all items in `vec` and in `other` and return them as a ProductNode.
"""
struct ExtractKeyAsField{S,V} <: AbstractExtractor
	key::S
	item::V
end

extractsmatrix(s::ExtractKeyAsField) = false

function (e::ExtractKeyAsField)(v::V; store_input=false) where {V<:Union{Missing,Nothing}}
	BagNode(ProductNode((key = e.key(nothing, store_input=store_input), item = e.item(nothing, store_input=store_input)))[1:0], [0:-1])
end

function (e::ExtractKeyAsField)(vs::Dict; store_input=false)
	isempty(vs) && return(e(nothing, store_input=store_input))
	items = map(collect(vs)) do (k,v)
		ProductNode((key = e.key(k, store_input=store_input), item = e.item(v, store_input=store_input)))
	end
	BagNode(reduce(catobs, items), [1:length(vs)])
end

Base.hash(e::ExtractKeyAsField, h::UInt) = hash((e.key, e.item), h)
Base.:(==)(e1::ExtractKeyAsField, e2::ExtractKeyAsField) = e1.key == e2.key && e1.item == e2.item
