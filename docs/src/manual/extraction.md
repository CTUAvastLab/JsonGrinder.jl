```@setup extractor
using JsonGrinder
```

# Extraction

[`Extractor`](@ref) is responsible for converting JSON documents into
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures. The main idea is that the extractor
follows the same hierarchical structure as previously inferred [`Schema`](@ref). Extractor
for a whole JSON is created by composing (sub-)extractors while reflecting the JSON structure.

Assume the following dataset of two JSON documents for which we infer a [`Schema`](@ref):

```@example extractor
using JSON
```

```@repl extractor
jss = JSON.parse("""[
    {
        "name": "Karl",
        "siblings": ["Gertruda", "Heike", "Fritz"],
        "hobby": ["running", "pingpong"],
        "age": 21
    },
    {
        "name": "Heike",
        "siblings": ["Gertruda", "Heike", "Fritz"],
        "hobby": ["yoga"],
        "age": 24
    }
]""");
sch = schema(jss)
```

## Manual creation of [`Extractor`](@ref)s

One possible way to create an [`Extractor`](@ref) is to manually define it from all the required
pieces. One extractor corresponding to `sch` might look like this:

```@repl extractor
e = DictExtractor((
    name = NGramExtractor(),
    age = ScalarExtractor(),
    hobby = ArrayExtractor(CategoricalExtractor(["running", "swimming","yoga"]))
))
```

We have just created a [`DictExtractor`](@ref) with

- [`NGramExtractor`](@ref) to extract `String`s under the `"name"` key,
- [`ScalarExtractor`](@ref) to extract age under the `"age"` key, and finally
- [`ArrayExtractor`](@ref) for extracting arrays under the `"hobby"` key. This extractor has one
  child, a [`CategoricalExtractor`](@ref), which operates on three hobby categories.

Applying `e` on the first JSON document yields the following hierarchy of
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures:

```@repl extractor
x = e(jss[1])
```

!!! ukn "Missing key"
    Note that we didn't include any extractor for the `"siblings"` key. In such case, the
    key in the JSON document is simply ignored and never extracted.

Every (sub)extractor, a node in the extractor "tree" is also callable, for example:

```@repl extractor
e[:hobby](jss[1]["hobby"])
```

Let's inspect how the subtree under the `"hobby"` key in the JSON was extracted:

```@repl extractor
printtree(x; trav=true)
x["s"]
```

The first column in the `OneHotMatrix` corresponds to `"running"`, which is the first category in
the corresponding [`CategoricalExtractor`](@ref). The second column corresponds to `"pingpong"`,
which is an *unknown* category in the extractor. Any other unknown `String` would be extracted in
the same way:

```@repl extractor
e["s"]("unknown")
```

!!! ukn "Further reading"
    For more information about individual subtypes of [`Extractor`](@ref), see their docs, or
    [Extractor API](@ref extractor_api).

## Semi-automatic [`Extractor`](@ref) creation

Manually creating [`Extractor`](@ref)s is a laborous and error-prone process once the hierarchical
structure of input JSON documents gets large. For this reason,
[`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) provides the
[`suggestextractor`](@ref) function greatly simplifying this process:

```@repl extractor
e = suggestextractor(sch)
```

The function uses a simple heuristic for choosing reasonable extractors for values in leaves: if
there are not many unique values (less than the `categorical_limit` keyword argument), use
[`CategoricalExtractor`](@ref), else use either [`NGramExtractor`](@ref) or
[`ScalarExtractor`](@ref) depending on the type.

!!! ukn "Hooking into the behavior"
    It is possible to hook into the internals of how [`suggestextractor`](@ref) treats values in
    leaves by redefining `_suggestextractor(e::LeafEntry)`.

Please refer to the [`suggestextractor`](@ref) docs for all possible keyword arguments.

!!! ukn "Inspect the result"
    It is **recommended** to check the proposed extractor manually, and modifying it if it makes
    sense.

## Stable [`Extractor`](@ref)s

Sometimes not all JSON documents in a dataset are complete. For example:

```@repl extractor
jss = JSON.parse.([
    """ { "a" : 1, "b" : "foo" } """,
    """ { "b" : "bar" } """
]);
sch = schema(jss)
```

In such case, [`suggestextractor`](@ref) wraps the extractor corresponding to the key with
missing data (`"a"`) into [`StableExtractor`](@ref):

```@repl extractor
e = suggestextractor(sch)
```

and the extraction works fine:

```@repl extractor
extract(e, jss)
```

If the dataset for schema inference is undersampled and the missing key doesn't show up, [`suggestextractor`](@ref) will infer unsuitable [`Extractor`](@ref):

```@repl extractor
sch = schema(jss[1:1])
e = suggestextractor(sch)
e(jss[2])
```

There are multiple ways to deal with this problem:

- Manually wrap the problematic node (here with the help of
   [`Accessors.jl`](https://github.com/JuliaObjects/Accessors.jl)):

```@example extractor
using Accessors
```
```@repl extractor
e_stable = @set e.children[:a] = StableExtractor(e[:a])
e_stable(jss[2])
```

- Use [`stabilizeextractor`](@ref) on the whole tree (or a subtree):

```@repl extractor
e_stable = stabilizeextractor(e)
e_stable(jss[2])
```

- Call [`suggestextractor`](@ref) with `all_stable=true`. Now all document values are treated as
  possibly missing. Results of `stabilizeextractor(schema(...))` and `suggestextractor(...; all_stable=true)`
  are roughly equivalent:

```@repl extractor
e_stable = suggestextractor(sch; all_stable=true)
e_stable(jss[2])
```

- Preprocess the data (delete the problematic key from all documents or the schema, or make sure
   that documents with the missing key are present in the data when calling [`schema`](@ref)).
