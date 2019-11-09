"""
	MultipleRepresentation(extractors::Tuple)

	crate a `ProductNode` where each item is the json part 
	processed by all extractors in the order

"""
struct MultipleRepresentation{E<:Tuple}
	extractors::E
end


function (m::MultipleRepresentation)(x)
	TreeNode(map(e -> e(x), m.extractors))
end