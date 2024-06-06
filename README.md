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

Kindly cite our work with the following entries if you find it interesting, please:

* [*JsonGrinder.jl: automated differentiable neural architecture for embedding arbitrary JSON
  data*](https://jmlr.org/papers/v23/21-0174.html)

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

* [*Malicious Internet Entity Detection Using Local Graph
  Inference*](https://ieeexplore.ieee.org/document/10418120) (practical `Mill.jl` and
  `JsonGrinder.jl` application)

  ```
  @article{Mandlik2024,
    author  = {Mandlík, Šimon and Pevný, Tomáš and Šmídl, Václav and Bajer, Lukáš},
    journal = {IEEE Transactions on Information Forensics and Security},
    title   = {Malicious Internet Entity Detection Using Local Graph Inference},
    year    = {2024},
    volume  = {19},
    pages   = {3554-3566},
    doi     = {10.1109/TIFS.2024.3360867}
  }
  ```

* this implementation (fill in the used `version`):

  ```
  @software{JsonGrinder,
    author  = {Tomas Pevny and Matej Racinsky and Simon Mandlik},
    title   = {JsonGrinder.jl: a flexible library for automated feature engineering and conversion of JSONs to Mill.jl structures},
    url     = {https://github.com/CTUAvastLab/JsonGrinder.jl},
    version = {...},
  }
  ```

## Contribution guidelines

If you want to contribute to JsonGrinder.jl, be sure to review the
[contribution guidelines](CONTRIBUTING.md).

We use [GitHub issues](https://github.com/CTUAvastLab/JsonGrinder.jl/issues) for
tracking requests and bugs.
