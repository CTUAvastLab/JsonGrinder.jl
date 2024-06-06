<p align="center">
  <img src="https://github.com/CTUAvastLab/JsonGrinder.jl/raw/master/docs/src/assets/logo.svg#gh-light-mode-only" alt="JsonGrinder.jl logo"/>
  <img src="https://github.com/CTUAvastLab/JsonGrinder.jl/raw/master/docs/src/assets/logo-dark.svg#gh-dark-mode-only" alt="JsonGrinder.jl logo"/>
</p>

---

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/CTUAvastLab/JsonGrinder.jl/blob/master/LICENSE.md)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://CTUAvastLab.github.io/JsonGrinder.jl/stable)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://CTUAvastLab.github.io/JsonGrinder.jl/dev)
[![Build Status](https://github.com/CTUAvastLab/JsonGrinder.jl/workflows/CI/badge.svg)](https://github.com/CTUAvastLab/JsonGrinder.jl/actions?query=workflow%3ACI)
[![codecov.io](http://codecov.io/github/CTUAvastLab/JsonGrinder.jl/coverage.svg?branch=master)](http://codecov.io/github/CTUAvastLab/JsonGrinder.jl?branch=master)

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

## Getting Started

- [Documentation](https://ctuavastlab.github.io/JsonGrinder.jl/stable/)
- [API Reference](https://ctuavastlab.github.io/JsonGrinder.jl/stable/api/aggregation/)
- [Examples](https://ctuavastlab.github.io/JsonGrinder.jl/stable/examples/mutagenesis/mutagenesis/)

## Citation

For citing, please use the following entry for the [original paper](https://jmlr.org/papers/v23/21-0174.html):
```
@article{Mandlik2021,
  author  = {Šimon Mandlík and Matěj Račinský and Viliam Lisý and Tomáš Pevný},
  title   = {JsonGrinder.jl: automated differentiable neural architecture for embedding arbitrary JSON data},
  journal = {Journal of Machine Learning Research},
  year    = {2022},
  volume  = {23},
  number  = {298},
  pages   = {1--5},
  url     = {http://jmlr.org/papers/v23/21-0174.html}
}
```

and the following for this implementation (fill in the used `version`):
```
@software{jsongrinder2019,
  author = {Tomas Pevny and Matej Racinsky},
  title = {JsonGrinder.jl: a flexible library for automated feature engineering and conversion of JSONs to Mill.jl structures},
  url = {https://github.com/CTUAvastLab/JsonGrinder.jl},
  version = {...},
}
```

## Contribution guidelines

If you want to contribute to JsonGrinder.jl, be sure to review the
[contribution guidelines](CONTRIBUTING.md).

We use [GitHub issues](https://github.com/CTUAvastLab/JsonGrinder.jl/issues) for
tracking requests and bugs.
