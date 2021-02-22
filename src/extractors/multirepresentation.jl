"""
	MultipleRepresentation(extractors::Tuple)

	crate a `ProductNode` where each item is the json part
	processed by all extractors in the order

"""
struct MultipleRepresentation{E<:Union{NamedTuple, Tuple}}
	extractors::E
end

MultipleRepresentation(vs::Vector) = MultipleRepresentation((;[Symbol("e$(i)") => v for (i,v) in enumerate(vs)]...))
MultipleRepresentation(vs::Tuple) = MultipleRepresentation((;[Symbol("e$(i)") => v for (i,v) in enumerate(vs)]...))
(m::MultipleRepresentation)(x; store_input=false) = ProductNode(map(e -> e(x, store_input=store_input), m.extractors))

extractsmatrix(s::MultipleRepresentation) = false

Base.hash(e::MultipleRepresentation, h::UInt) = hash(e.extractors, h)
Base.:(==)(e1::MultipleRepresentation, e2::MultipleRepresentation) = e1.extractors == e2.extractors
Base.getindex(e::MultipleRepresentation, i::Int) = e.extractors[i]
