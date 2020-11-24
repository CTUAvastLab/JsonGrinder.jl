
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
# todo: dodělat missingy, všchny nothing předělat na missing a pořádně to otestovat
function (e::ExtractKeyAsField)(v::V) where {V<:Union{Missing,Nothing}}
	BagNode(ProductNode((key = e.key(nothing), item = e.item(nothing)))[1:0], [0:-1])
end

function (e::ExtractKeyAsField)(vs::Dict)
	isempty(vs) && return(e(nothing))
	items = map(collect(vs)) do (k,v)
		ProductNode((key = e.key(k), item = e.item(v)))
	end
	BagNode(reduce(catobs, items), [1:length(vs)])
end

Base.hash(e::ExtractKeyAsField, h::UInt) = hash((e.key, e.item), h)
Base.:(==)(e1::ExtractKeyAsField, e2::ExtractKeyAsField) = e1.key == e2.key && e1.item == e2.item
