import Mill: catobs, MaybeHotMatrix
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

function (s::ExtractCategorical{V,I})(v::V) where {V,I}
    x = MaybeHotMatrix([get(s.keyvalemap, v, s.n)], s.n)
    ArrayNode(x)
end

function (s::ExtractCategorical{V,I})(vs::Vector{V}) where {V,I}
	x = MaybeHotMatrix([get(s.keyvalemap, v, s.n) for v in vs], s.n)
	ArrayNode(x)
end

function (s::ExtractCategorical{V,I})(vs::Vector{<:Union{V, Missing, Nothing}}) where {V,I}
	x = MaybeHotMatrix([ismissing(v) || isnothing(v) ? missing : get(s.keyvalemap, v, s.n) for v in vs], s.n)
	ArrayNode(x)
end

# todo: dodělat missingy, všchny nothing předělat na missing a pořádně to otestovat
(s::ExtractCategorical)(::V) where {V<:Union{Missing, Nothing}} = ArrayNode(MaybeHotMatrix([missing], s.n))
(s::ExtractCategorical)(::ExtractEmpty) = ArrayNode(MaybeHotMatrix(Vector{Int}(), s.n))
(s::ExtractCategorical)(v) = s(missing)

Base.reduce(::typeof(catobs), a::Vector{S}) where {S<:Flux.OneHotMatrix} = _catobs(a[:])
catobs(a::Flux.OneHotMatrix...) = _catobs(collect(a))
_catobs(a::AbstractArray{<:Flux.OneHotMatrix}) = Flux.OneHotMatrix(a[1].height,reduce(vcat, [i.data for i in a]))

Base.hash(e::ExtractCategorical, h::UInt) = hash((e.keyvalemap, e.n), h)
Base.:(==)(e1::ExtractCategorical, e2::ExtractCategorical) = e1.keyvalemap == e2.keyvalemap && e1.n === e2.n
