# # Schema Examination
# In this example we build schema of documents with complex structure and show how can we filter it and perform transformations.
# We start by adding libraries we want to use

#md # !!! tip
#md #     This example is also available as a Jupyter notebook, feel free to run it yourself:
#md #     [`schema_examination.ipynb`](@__NBVIEWER_ROOT_URL__/examples/schema_examination.ipynb)

#nb # We start by installing JsonGrinder and few other packages we need for the example.
#nb # Julia Ecosystem follows philosophy of many small single-purpose composable packages
#nb # which may be different from e.g. python where we usually use fewer larger packages.
#nb using Pkg
#nb pkg"add JsonGrinder Flux Mill MLDataPattern JSON HierarchicalUtils StatsBase"

using JsonGrinder, Flux, Mill, MLDataPattern, JSON, HierarchicalUtils, StatsBase
using JsonGrinder: DictEntry, Entry

# We load files in data/documents and parse them
data_dir = "data/documents" #src
data_dir = "../../../data/documents" #nb
data_dir = "data/documents" #md
data_dir = "data/documents" #jl
sch = JsonGrinder.schema(readdir(data_dir, join=true), x->open(JSON.parse, x))
# The default printing method restricts depth and width of the printed schema.
# We can see the whole schema using the `printtree` function from `HierarchicalUtils`.
printtree(sch)

# This is how some of the documents look like:
open(JSON.parse, first(readdir(data_dir, join=true)))

# We suggest default extractor.
extractor = suggestextractor(sch)

# We show the whole extractor.
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
		(e, uniontypes) -> MultipleRepresentation((
			ExtractCategorical(top_n_keys(e, 20), uniontypes),
			extractscalar(unify_types(e), e, uniontypes)
		)))
	], JsonGrinder.default_scalar_extractor())
end

top_n_keys(e::Entry, n::Int) = map(x->x[1], sort(e.counts |> collect, by=x->x[2], rev=true)[begin:min(n, end)])
suggestextractor(sch, (;
	scalar_extractors=string_multi_representation_scalar_extractor(),
	key_as_field=13,
	)
) |> printtree
unify_types(sch[:paper_id]) <: String
