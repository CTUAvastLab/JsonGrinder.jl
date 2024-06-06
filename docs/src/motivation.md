# Motivation

Imagine that you want to train a model for processing hierarchical JSON documents. One example
of a JSON document describing a molecule measurements may look like this:

```json
{
    "ind1": 1,
    "inda": 0,
    "logp": 6.01,
    "lumo": -2.184,
    "atoms": [
        {
            "element": "c",
            "atom_type": 22,
            "charge": -0.118,
            "bonds": [
                { "bond_type": 7, "element": "c", "atom_type": 22, "charge": -0.118 },
                { "bond_type": 1, "element": "h", "atom_type": 3, "charge": 0.141 },
                { "bond_type": 7, "element": "c", "atom_type": 22, "charge": -0.118 }
            ]
        },
        {
            "element": "c",
            "atom_type": 27,
            "charge": 0.012,
            "bonds": [
                { "bond_type": 7, "element": "c", "atom_type": 22, "charge": -0.118 },
                { "bond_type": 7, "element": "c", "atom_type": 27, "charge": -0.089 },
                { "bond_type": 7, "element": "c", "atom_type": 22, "charge": -0.118 }
            ]
        }
    ]
}
```

We would like to predict the mutagenicity for Salmonella typhimurium of this molecule (for example,
the example above is mutagenic).

Majority of machine learning libraries assume the data takes form of tensors of a fixed dimension
(like vectors or images) or a sequence of such tensors.

In contrast, [`JsonGrider.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) only requires your
data to be stored in a flexible JSON format, and tries to automate most labor using reasonable
defaults, while still giving you an option to control and tweak almost everything.
[`JsonGrider.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) is built on top of
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) which itself is built on top of
[`Flux.jl`](https://fluxml.ai/).

!!! unk "Other formats"
    Although JsonGrinder was designed for JSON files, it can easily be adapted for XML, [Protocol
    Buffers](https://developers.google.com/protocol-buffers),
    [MessagePack](https://msgpack.org/index.html), and other similar formats.

## Pipeline structure

Standard [`JsonGrinder.jl`](https://github.com/CTUAvastLab/JsonGrinder.jl) pipeline usually consists
of five steps:

1. Create a *schema* of JSON files (using [`schema`](@ref)).
2. From this schema create an *extractor* converting JSONs to
   [`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures (e.g. using
   [`suggestextractor`](@ref)).
3. Extract your JSON documents into [`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures
   with the extractor (e.g. with [`extract`](@ref)). If all data fits into memory, extract
   everything at once, or extract on-demand when training.
4. Define a suitable model (e.g. using [`Mill.reflectinmodel`](@ref)).
5. Train the model, the library is 100% compatible with the [`Flux.jl`](https://fluxml.ai/) tooling.

The basic workflow can be visualized as follows:

```@raw html
<img class="display-light-only" src="../../assets/workflow.svg" alt="JsonGrinder workflow" style="width: 30%;"/>
<img class="display-dark-only" src="../../assets/workflow-dark.svg" alt="JsonGrinder workflow" style="width: 30%;"/>
```

The framework is able to process hierarchical JSON documents of any schema, embedding the documents
into vectors. The embeddings can be used for classification, regression, and other ML tasks. Thanks
to [`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl), models can handle missing values at all
levels.

See [Mutagenesis](@ref) for complete example of processing JSONs like the one above, including code.
