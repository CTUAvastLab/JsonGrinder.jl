
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

function (e::ExtractKeyAsField)(v::MissingOrNothing; store_input=false)
	Mill._emptyismissing[] && return _make_bag_node(missing, [0:-1], [v], store_input)
	ds = ProductNode((key = e.key(extractempty; store_input), item = e.item(extractempty; store_input)))[1:0]
	_make_bag_node(ds, [0:-1], [v], store_input)
end

(e::ExtractKeyAsField)(v::ExtractEmpty; store_input=false) =
	make_empty_bag(ProductNode((key = e.key(v; store_input), item = e.item(v; store_input))), v)

function (e::ExtractKeyAsField)(vs::Dict; store_input=false)
	isempty(vs) && return e(missing; store_input)
	items = map(collect(vs)) do (k,v)
		ProductNode((key = e.key(k; store_input), item = e.item(v; store_input)))
	end
	_make_bag_node(reduce(catobs, items), [1:length(vs)], [vs], store_input)
end

Base.hash(e::ExtractKeyAsField, h::UInt) = hash((e.key, e.item), h)
Base.:(==)(e1::ExtractKeyAsField, e2::ExtractKeyAsField) = e1.key == e2.key && e1.item == e2.item
