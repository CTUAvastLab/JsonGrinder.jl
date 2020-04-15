"""
	MultipleRepresentation(extractors::Tuple)

	crate a `ProductNode` where each item is the json part
	processed by all extractors in the order

"""
struct MultipleRepresentation{E<:Tuple}
	extractors::E
end

MultipleRepresentation(v::Vector) = MultipleRepresentation(tuple(v...))
(m::MultipleRepresentation)(x) = ProductNode(map(e -> e(x), m.extractors))

extractsmatrix(s::MultipleRepresentation) = false

Base.hash(e::MultipleRepresentation, h::UInt) = hash(e.extractors, h)
Base.:(==)(e1::MultipleRepresentation, e2::MultipleRepresentation) = e1.extractors == e2.extractors
