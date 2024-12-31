```@raw html
<img class="display-light-only" src="assets/logo.svg" alt="JsonGrinder.jl logo" style="width: 70%;"/>
<img class="display-dark-only" src="assets/logo-dark.svg" alt="JsonGrinder.jl logo" /style="width: 70%;">
```

`JsonGrinder.jl` is a library that facilitates processing of JSON documents into
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) structures for machine learning. It provides
functionality for JSON schema inference, extraction of JSON documents to a suitable representation
for machine learning, and constructing a model operating on this data.

Watch our [introductory talk](https://www.youtube.com/watch?v=Bf0CvltIDbE) from JuliaCon 2021.

## Installation

Run the following in REPL:

```julia
] add JsonGrinder
```

Julia v1.10 or later is required.

## Getting started

For the quickest start, see the [Mutagenesis](@ref) example.

* [Motivation](@ref): a brief introduction and motivation
* [Manual](@ref manual_schema): a tutorial about the package
* [Examples](@ref Mutagenesis): a collection of examples
* [External tools](@ref HierarchicalUtils.jl): examples of integration with other packages
* [Public API](@ref schema_api): extensive API reference
* [Citation](@ref): preferred citation entries
* [`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl): a core dependence of the package
