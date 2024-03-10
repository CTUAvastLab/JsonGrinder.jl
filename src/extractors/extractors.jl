abstract type AbstractExtractor end
abstract type BagExtractor <: AbstractExtractor end

# """
#     struct ExtractEmpty end
#
# Concrete type to dispatch on for extraction of empty samples.
# """
# struct ExtractEmpty end
#
# """
#     extractempty
#
# A singleton of type [`ExtractEmpty`](@ref) is used to signal
# downstream extractors that they should extract an empty sample.
# """
# const extractempty = ExtractEmpty()
#
# const MissingOrNothing = Union{Missing, Nothing}
# const HierarchicType = Union{AbstractDict, AbstractVector, StringOrNumber, MissingOrNothing, ExtractEmpty}
#
# _make_array_node(x, v, store_input) = store_input ? ArrayNode(x, v) : ArrayNode(x)
# _make_bag_node(x, bags, v, store_input) = store_input ? BagNode(x, bags, v) : BagNode(x, bags)
#
# """
# returns empty bag of 0 observations
# """
# make_empty_bag(x, v) = BagNode(x, Mill.AlignedBags(Vector{UnitRange{Int64}}()))
#
# include("auxiliary.jl")
# include("extractarray.jl")
# include("extractdict.jl")
# include("extractcategorical.jl")
# include("extractscalar.jl")
# include("extractstring.jl")
# include("extractvector.jl")
# include("extract_keyasfield.jl")
# TODO error here. It's hard to make multirepresentation consistent
# include("multirepresentation.jl")
#
# make_representative_sample(sch::AbstractJSONEntry, ex::AbstractExtractor) = ex(sample_synthetic(sch))
#
# function Mill.reflectinmodel(sch::AbstractJSONEntry, ex::AbstractExtractor, args...; kwargs...)
#     # because we have type-stable extractors, we now have information about what is missing and what not inside types
#     # so I don't have to extract empty and missing samples, the logic is now part of suggestextractor
#     specimen = make_representative_sample(sch, ex)
#     reflectinmodel(specimen, args...; kwargs...)
# end
# function suggestextractor(e::LeafEntry, settings = NamedTuple(); path::String = "", child_less_than_parent = false)
#     t = unify_types(e::LeafEntry)
#     t == Any && @error "$(path): JSON does not have a fixed type scheme, quitting"
#
#     for (c, ex) in get(settings, :scalar_extractors, default_scalar_extractor())
#         c(e) && return ex(e, child_less_than_parent)
#     end
# end
#
# # todo: here add argument and decide if it should be full or not
# function default_scalar_extractor(;small_categorical_max_dimension=100, large_categorical_min_occurences=10, large_categorical_max_dimension=min(10000, max_keys()))
# 	[
# 	(e -> length(keys(e)) < small_categorical_max_dimension,
# 		(e, uniontypes) -> ExtractCategorical(keys(e), uniontypes)),
# 	(e -> is_intable(e),
# 		(e, uniontypes) -> extractscalar(Int32, e, uniontypes)),
# 	(e -> is_floatable(e),
# 	 	(e, uniontypes) -> extractscalar(FloatType, e, uniontypes)),
# 	# it's important that condition here would be lower than maxkeys
# 	(e -> (keys_len = length(keys(e)); large_categorical_min_occurences * keys_len <= sum(values(e.counts)) && keys_len < large_categorical_max_dimension && !is_numeric_or_numeric_string(e)),
# 		(e, uniontypes) -> ExtractCategorical(keys(e), uniontypes)),
# 	(e -> true,
# 		(e, uniontypes) -> extractscalar(unify_types(e), e, uniontypes)),]
# end
#
# """
# 	suggestextractor(e::DictEntry, settings = NamedTuple())
#
# create convertor of json to tree-structure of `DataNode`
#
# - `e` top-level of json hierarchy, typically returned by invoking schema
# - `settings` can be any container supporting `get` function
# - `settings.mincountkey` contains minimum repetition of the key to be included into the extractor
#   (if missing it is equal to zero)
# - `settings.key_as_field` of the number of keys exceeds this value, it is assumed that keys contains a value,
#   which means that they will be treated as strings.
# - `settings.scalar_extractors` contains rules for determining which extractor to use for leaves.
#   Default value is return value of `default_scalar_extractor()`, it's array of pairs where first element is predicate
#   and if it matches, second element, function which maps schema to specific extractor, is called.
# """
# function suggestextractor(e::DictEntry, settings = NamedTuple(); path = "", child_less_than_parent = false)
# 	length(e.childs) >= get(settings, :key_as_field, 500) && return key_as_field(e, settings;
# 		path = path, child_less_than_parent = child_less_than_parent)
#
# 	for k in filter(k->!isnothing(e.childs[k]) && isempty(e.childs[k]), keys(e.childs))
# 		@warn "$(path): key $k contains empty array, skipping"
# 	end
# 	ks = filter(k->!isempty(e.childs[k]), keys(e.childs))
# 	mincount = get(settings, :mincountkey, 0)
# 	ks = filter(k -> updated(e.childs[k]) > mincount, ks)
# 	isempty(ks) && return nothing
# 	c = [(k,suggestextractor(e.childs[k], settings,
# 			path = path*"[:$(k)]",
# 			child_less_than_parent = child_less_than_parent || e.updated > e.childs[k].updated)
# 		) for k in ks]
# 	c = filter(s -> s[2] != nothing, c)
# 	isempty(c) && return nothing
# 	ExtractDict(Dict(c))
# end
#
# # todo: benchmark on large cuckoo schemas, and optimize if needed
# function suggestextractor(e::MultiEntry, settings = NamedTuple(); path = "", child_less_than_parent = false)
# 	# consolidation of types, type wrangling of numeric strings takes place here
# 	# trying to unify types and create new child entries for them. Merging string + numbers
# 	e = merge_entries_with_cast(e, Int32, Real)
# 	e = merge_entries_with_cast(e, FloatType, Real)
# 	# we need to filter out empty things in multientry too, same manner as dict
# 	ks = filter(k->!isempty(e.children[k]), keys(e.children))
# 	# child extractors of multi representation will always gene incompatible type which is treated as missing
# 	# otherwise there would not be the need for MultiRepresentation at all
# 	# that's why we enforce true here
# 	MultipleRepresentation(map(k -> suggestextractor(e.children[k], settings,
# 			path = path,
# 			# in case of numberic strings and numbers I may have full samples so it should not be uniontype in such case
# 			child_less_than_parent = child_less_than_parent || length(e.children) > 1
# 		),ks))
# end
#
# # todo:
# #   logiku jestli to je missing nebo ne přesunout z sample_synthetic do suggestextractor
# #   pokud vrátím správné typy u full samplu, ověřit, jestli potřebuju empty sample nebo se to odvodí z plného
# function suggestextractor(node::ArrayEntry, settings = NamedTuple(); path = "", child_less_than_parent = false)
# 	if isempty(node)
# 		@warn "$(path) is an empty array, therefore I can not suggest extractor."
# 		return nothing
# 	end
#
# 	if length(node.l) == 1 && typeof(node.items) <: Entry && promote_type(unique(typeof.(keys(node.items.counts)))...) <: Number
# 		@info "$(path) is an array of numbers with of same length, therefore it will be treated as a vector."
# 		return ExtractVector(only(collect(keys(node.l))))
# 	end
# 	e = suggestextractor(node.items, settings, path = path, child_less_than_parent = child_less_than_parent)
# 	isnothing(e) ? e : ExtractArray(e)
# end
