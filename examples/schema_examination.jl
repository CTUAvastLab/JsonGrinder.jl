using Flux, MLDataPattern, Mill, JsonGrinder, JSON, HierarchicalUtils, StatsBase
using JsonGrinder: DictEntry

# load files in data/documents and parse them
sch = JsonGrinder.schema(readdir("data/documents", join=true), x->open(JSON.parse, x))
# suggest default extractor with some keys as field
extractor = suggestextractor(sch)
# show whole extractor
printtree(extractor)
# we see that there are some dictionaries with lots of keys, let's examine schema
# list_lens lets us iterate over all elements in a way we know their position in schema
# this prints lengths of children of all dict entries.
for i in list_lens(sch)
    e = get(sch, i)
    if e isa DictEntry
        @info i length(e.childs)
    end
end

# that's a lots of numbers, let's see histogram
length_hist = StatsBase.countmap([length(get(sch, i).childs) for i in list_lens(sch) if get(sch, i) isa DictEntry])

# we see highest lengths are 103 and 13, let's set 13 as a threshold
extractor = suggestextractor(sch, (; key_as_field=13))
# show new extractor
printtree(extractor)
# this extractor looks much better
# but still, some values are very sparse,
# let's print all parts of schema where each value is observed only once
for i in list_lens(sch)
    e = get(sch, i)
    if e isa Entry && maximum(values(e.counts)) == 1
        @info i
    end
end

#  we can see lots of leaves under `bib_entries`, which is cased by uniqueness of keys here
# but apart from that, we can see other interesting fields
# [ Info: (@lens _.childs[:metadata].childs[:authors].items.childs[:middle].items)
# [ Info: (@lens _.childs[:metadata].childs[:authors].items.childs[:last])
# [ Info: (@lens _.childs[:metadata].childs[:authors].items.childs[:affiliation].childs[:location].childs[:region])
# [ Info: (@lens _.childs[:paper_id])
# [ Info: (@lens _.childs[:body_text].items.childs[:text])
# [ Info: (@lens _.childs[:body_text].items.childs[:ref_spans].items.childs[:start])
# [ Info: (@lens _.childs[:body_text].items.childs[:ref_spans].items.childs[:end])
# [ Info: (@lens _.childs[:back_matter].items.childs[:text])
# [ Info: (@lens _.childs[:back_matter].items.childs[:cite_spans].items.childs[:ref_id])
# [ Info: (@lens _.childs[:back_matter].items.childs[:cite_spans].items.childs[:start])
# [ Info: (@lens _.childs[:back_matter].items.childs[:cite_spans].items.childs[:text])
# [ Info: (@lens _.childs[:back_matter].items.childs[:cite_spans].items.childs[:end])
# [ Info: (@lens _.childs[:back_matter].items.childs[:ref_spans].items.childs[:start])
# [ Info: (@lens _.childs[:back_matter].items.childs[:ref_spans].items.childs[:text])
# [ Info: (@lens _.childs[:back_matter].items.childs[:ref_spans].items.childs[:end])

# let's remove some of them from extractor
delete!(extractor.dict, :paper_id)
delete!(extractor.dict[:metadata].dict[:authors].item.dict, :last)
delete!(extractor.dict[:metadata].dict[:authors].item.dict, :middle)

# we can also notice, that some long texts are extracted as categorical variables, e.g.
extractor[:body_text].item[:text]
extractor[:body_text].item[:section]
# let's replace them manually by string extractors
# note that we need to use the .dict, as the [] accessor on item is just readonly syntax-sugar
extractor[:body_text].item.dict[:text] = ExtractString()
extractor[:body_text].item.dict[:section] = ExtractString()

# this concludes example about examining schema and modifying extractor accordingly.
using JsonGrinder: is_intable, is_floatable, unify_types, extractscalar
function string_multi_representation_scalar_extractor()
	vcat([
	(e -> unify_types(sch[:paper_id]) <: String,
		e -> MultipleRepresentation((
			ExtractCategorical(top_n_keys(e, 20)),
			extractscalar(unify_types(e), e)
		))
	], JsonGrinder.default_scalar_extractor()))
end

top_n_keys(e::Entry, n::Int) = map(x->x[1], sort(e.counts |> collect, by=x->x[2], rev=true)[begin:min(n, end)])
suggestextractor(sch, (;
	scalar_extractors=string_multi_representation_scalar_extractor(),
	key_as_field=13,
	)
) |> printtree
unify_types(sch[:paper_id]) <: String
