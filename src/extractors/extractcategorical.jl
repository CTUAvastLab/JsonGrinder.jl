import Mill.catobs
"""
	ExtractCategorical(s::Entry)
	ExtractCategorical(s::UnitRange)
	ExtractCategorical(s::Vector)

	Converts a single item to a one-hot encoded vector. There is always alocated an extra
	element for a unknown value
"""
struct ExtractCategorical{V,I} <: AbstractExtractor
	keyvalemap::Dict{V,I}
	n::Int
end

ExtractCategorical(s::Entry) = ExtractCategorical(collect(keys(s.counts)))
ExtractCategorical(s::UnitRange) = ExtractCategorical(collect(s))
function ExtractCategorical(ks::Vector)
	if isempty(ks)
		@warn "Skipping initializing empty categorical variable does not make much sense to me"
		return(nothing)
	end
	ks = sort(unique(ks));
	ExtractCategorical(Dict(zip(ks, 1:length(ks))), length(ks) +1)
end


extractsmatrix(s::ExtractCategorical) = false

function (s::ExtractCategorical{V,I})(v::V; store_input=false) where {V,I}
    x = Flux.OneHotMatrix(s.n,[Flux.OneHotVector(get(s.keyvalemap, v, s.n), s.n)])
    store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end

function (s::ExtractCategorical{V,I})(vs::Vector{V}; store_input=false) where {V,I}
	x = Flux.OneHotMatrix(s.n,[Flux.OneHotVector(get(s.keyvalemap, v, s.n), s.n) for v in vs])
	store_input ? ArrayNode(x, vs) : ArrayNode(x)
end

function (s::ExtractCategorical)(v::Nothing; store_input=false)
	x = Flux.OneHotMatrix(s.n,[Flux.OneHotVector(s.n, s.n)])
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end
function (s::ExtractCategorical)(v; store_input=false)
	# we default to nothing. So this is hardcoded to nothing. Todo: dedupliate it
	x = Flux.OneHotMatrix(s.n,[Flux.OneHotVector(s.n, s.n)])
	store_input ? ArrayNode(x, [v]) : ArrayNode(x)
end

Base.reduce(::typeof(catobs), a::Vector{S}) where {S<:Flux.OneHotMatrix} = _catobs(a[:])
catobs(a::Flux.OneHotMatrix...) = _catobs(collect(a))
_catobs(a::AbstractArray{<:Flux.OneHotMatrix}) = Flux.OneHotMatrix(a[1].height,reduce(vcat, [i.data for i in a]))

Base.hash(e::ExtractCategorical, h::UInt) = hash((e.keyvalemap, e.n), h)
Base.:(==)(e1::ExtractCategorical, e2::ExtractCategorical) = e1.keyvalemap == e2.keyvalemap && e1.n === e2.n
