<p align="center">
 <img src="https://raw.githubusercontent.com/CTUAvastLab/JsonGrinder.jl/master/docs/src/assets/logo.svg" alt="JsonGrinder.jl logo"/>
</p>

---

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/CTUAvastLab/JsonGrinder.jl/blob/master/LICENSE.md)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://CTUAvastLab.github.io/JsonGrinder.jl/stable)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://CTUAvastLab.github.io/JsonGrinder.jl/dev)
[![Build Status](https://github.com/CTUAvastLab/JsonGrinder.jl/workflows/CI/badge.svg)](https://github.com/CTUAvastLab/JsonGrinder.jl/actions?query=workflow%3ACI)
[![Coverage Status](https://coveralls.io/repos/github/CTUAvastLab/JsonGrinder.jl/badge.svg?branch=master)](https://coveralls.io/github/CTUAvastLab/JsonGrinder.jl?branch=master)
[![codecov.io](http://codecov.io/github/CTUAvastLab/JsonGrinder.jl/coverage.svg?branch=master)](http://codecov.io/github/CTUAvastLab/JsonGrinder.jl?branch=master)

**JsonGrinder** is a collection of routines that facilitates conversion of JSON documents into structures used by
[`Mill.jl`](https://github.com/CTUAvastLab/Mill.jl) project.

It provides schema estimation from data, extraction of various data types to numeric representation with
reasonable defaults, and suggestion of NN model structure based on data. For more details, see [the documentation](https://CTUAvastLab.github.io/JsonGrinder.jl/stable).

## Installation

Run the following in REPL:

```julia
] add JsonGrinder
```

## Citation

For citing, please use the following entry:

```
@misc{JsonGrinder2019,
    author = {Tomáš Pevný and Matěj Račinský},
    title = {{JsonGrinder.jl}},
    year = 2019,
    howpublished = "\url{https://github.com/CTUAvastLab/JsonGrinder.jl}"
}
```
