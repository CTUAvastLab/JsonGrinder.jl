"""
	MultipleRepresentation(extractors::Tuple)

	crate a `ProductNode` where each item is the json part
	processed by all extractors in the order

"""
struct MultipleRepresentation{E<:Tuple}
	extractors::E
end


(m::MultipleRepresentation)(x) = TreeNode(map(e -> e(x), m.extractors))

extractsmatrix(s::MultipleRepresentation) = false

function Base.show(io::IO, m::MultipleRepresentation; pad = [], key::String="")
	c = COLORS[(length(pad)%length(COLORS))+1]
	key *=": "
	paddedprint(io,"$(key)MultiRepresentation\n", color = c, pad = pad)
	if m.extractors != nothing
		printtuple(io, m.extractors, c = c, pad = pad)
	end
end

function printtuple(io, d::Tuple; c, pad, last::Bool = true)
	for i in 1:length(d)
  		p = (i == length(d)) ? "  └───" : "  ├───"
  		show(io, d[i], pad = vcat(replacebyspaces(pad), (c,p)) , key = " ")
 	end
end
