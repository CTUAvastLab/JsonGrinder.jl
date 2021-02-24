
"""
	struct ExtractKeyAsField{S,V} <: AbstractExtractor
		key::S
		item::V
	end

extracts all items in `vec` and in `other` and return them as a ProductNode.
"""
struct ExtractKeyAsField{S,V} <: BagExtractor
	key::S
	item::V
end

extract_empty_bag_item(e::ExtractKeyAsField, store_input) =
	ProductNode((key = e.key(extractempty; store_input), item = e.item(extractempty; store_input)))[1:0]

(s::ExtractKeyAsField)(v::MissingOrNothing; store_input=false) = extract_empty_bag_item(s, v; store_input)

(e::ExtractKeyAsField)(v::ExtractEmpty; store_input=false) =
	make_empty_bag(ProductNode((key = e.key(v; store_input), item = e.item(v; store_input))), v)

function (e::ExtractKeyAsField)(vs::Dict; store_input=false)
	isempty(vs) && return extract_missing_bag(e, vs; store_input)
	items = mapreduce(catobs, collect(vs)) do (k,v)
		ProductNode((key = e.key(k; store_input), item = e.item(v; store_input)))
	end
	_make_bag_node(items, [1:length(vs)], [vs], store_input)
end

Base.hash(e::ExtractKeyAsField, h::UInt) = hash((e.key, e.item), h)
Base.:(==)(e1::ExtractKeyAsField, e2::ExtractKeyAsField) = e1.key == e2.key && e1.item == e2.item
