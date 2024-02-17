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
#nb pkg"add JsonGrinder#master Flux Mill JSON HierarchicalUtils StatsBase OrderedCollections"

using JsonGrinder, Flux, Mill, JSON, HierarchicalUtils, StatsBase, OrderedCollections, Accessors
using JsonGrinder: DictEntry, Entry

data_dir = "data/documents" #src
data_dir = "../../../data/documents" #nb
data_dir = "../../../data/documents" #md
data_dir = "data/documents" #jl

# This is how some of the documents look like:
open(JSON.parse, first(readdir(data_dir, join=true)))

# We load files in data/documents and parse them
sch = JsonGrinder.schema(readdir(data_dir, join=true), x->open(JSON.parse, x))
# The default printing method restricts depth and width of the printed schema.
# We can see the whole schema using the `printtree` function from [HierarchicalUtils](https://github.com/CTUAvastLab/HierarchicalUtils.jl).
# The htrunc and vtrunc kwargs tell us maximum number of keys and max depth that will be rendered, respectively.
printtree(sch, htrunc=20, vtrunc=20)

# We suggest default extractor.
extractor = suggestextractor(sch)

# We show the almost whole extractor. Feel free to remove the htrunc and vtrunc kwargs if you want to
# see it whole.
printtree(extractor, htrunc=20, vtrunc=20)

# We see that there are some dictionaries with lots of keys, so let's examine the schema more.
# 
# Mill.jl [treats Dictionaries as a cartesian product of their embeddings](https://ctuavastlab.github.io/Mill.jl/stable/manual/nodes/#[ProductNode](@ref)s-and-[ProductModel](@ref)s)
# which does make sense in case when there is consistent number of keys, and keys themselves don't carry semantic meaning.
# Looking at the schema, we can hypothesize many different keys, which occur very scarcely in data, carry semantic information.
# 
# We want to examine how many unique keys are there in the schema in order to handle them differently and train also on key names in such case.
# So let's take a look at histogram of number of children per Dictionary.
# 
# Function [list_lens](https://ctuavastlab.github.io/Mill.jl/stable/api/utilities/#Mill.list_lens) ¨
# from [Mill.jl](https://github.com/CTUAvastLab/Mill.jl) lets us iterate over all nodes in our tree structure
# in a way we know their position in the schema.
dict_entries = filter(list_lens(sch)) do i
    n = Accessors.getall(sch, i) |> only
    n isa DictEntry
end
map(dict_entries) do i
    n = Accessors.getall(sch, i) |> only
    length(n.childs)
end |> countmap |> sort

# We see that 1 dict has 103 unique children, 1 dict has 13 unique children, 
# 91 dicts have 9 unique children, 59 dicts don't have any children etc.
# 
# We can take a more detailed look at Dicts with > 5 children.
# 
# The following code prints paths to all Dictionaries in the schema and number of their children if they have more than 5 children.
# In total there is lots of diction
for i in list_lens(sch)
    e = Accessors.getall(sch, i) |> only
    if e isa DictEntry && length(e.childs) > 5
        @info i length(e.childs)
    end
end

# The dictionaries with most unique children are following ones:
# ```
# ┌ Info: (@optic _.childs[:ref_entries])
# └   length(e.childs) = 13
# ┌ Info: (@optic _.childs[:bib_entries])
# └   length(e.childs) = 103
# ```
# because this is where keys have semantic meaning.
# JsonGrinder contains [ExtractKeyAsField](@ref) extractor, which treats 
# dictionaries with large number of keys as array of pairs (key, value)
# which leads to more reasonable model. 
# 
# There is a default value, but we want to set it ourselves to 13 to cover
# both cases we see in out data. This can be performed by creating new extractor
# like this
extractor = suggestextractor(sch, (; key_as_field=13))

# When we look at the larger part of extractor
printtree(extractor, htrunc=20, vtrunc=20)
# we now see represenation of `bib_entries` and `ref_entries` is
# more reasonable now.
# 
# So we can say this extractor looks much better.
# 
# But still, some values are very sparse,
# let's print all parts of schema where each value is observed only once
for i in list_lens(sch)
    e = Accessors.getall(sch, i) |> only
    if e isa Entry && maximum(values(e.counts)) == 1
        @info i
    end
end

#  we can see lots of leaves under `bib_entries`, which is cased by uniqueness of keys here
# but apart from that, we can see other interesting fields
# ```
# [ Info: (@optic _.childs[:metadata].childs[:authors].items.childs[:middle].items)
# [ Info: (@optic _.childs[:metadata].childs[:authors].items.childs[:last])
# [ Info: (@optic _.childs[:metadata].childs[:authors].items.childs[:affiliation].childs[:location].childs[:region])
# [ Info: (@optic _.childs[:paper_id])
# [ Info: (@optic _.childs[:body_text].items.childs[:text])
# [ Info: (@optic _.childs[:body_text].items.childs[:ref_spans].items.childs[:start])
# [ Info: (@optic _.childs[:body_text].items.childs[:ref_spans].items.childs[:end])
# [ Info: (@optic _.childs[:back_matter].items.childs[:text])
# [ Info: (@optic _.childs[:back_matter].items.childs[:cite_spans].items.childs[:ref_id])
# [ Info: (@optic _.childs[:back_matter].items.childs[:cite_spans].items.childs[:start])
# [ Info: (@optic _.childs[:back_matter].items.childs[:cite_spans].items.childs[:text])
# [ Info: (@optic _.childs[:back_matter].items.childs[:cite_spans].items.childs[:end])
# [ Info: (@optic _.childs[:back_matter].items.childs[:ref_spans].items.childs[:start])
# [ Info: (@optic _.childs[:back_matter].items.childs[:ref_spans].items.childs[:text])
# [ Info: (@optic _.childs[:back_matter].items.childs[:ref_spans].items.childs[:end])
# ```
# 
# Let's remove some of them from the extractor so we don't train on them.
delete!(extractor.dict, :paper_id)
delete!(extractor.dict[:metadata].dict[:authors].item.dict, :last)
delete!(extractor.dict[:metadata].dict[:authors].item.dict, :middle)

# Now the extractor looks even better!
printtree(extractor, htrunc=20, vtrunc=20)

# This concludes example about examining schema and modifying extractor accordingly.
