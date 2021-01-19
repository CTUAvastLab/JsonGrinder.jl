```@setup hierarchical
using Mill
using StatsBase: nobs
```

# HierarchicalUtils.jl
JsonGrinder.jl uses [HierarchicalUtils.jl](https://github.com/Sheemon7/HierarchicalUtils.jl) which brings a lot of additional features.

```@example hierarchical
using HierarchicalUtils
```

<!--
todo: finish this:
We can find them programmatically by running
```julia
julia> filter(e->sch[e] isa JsonGrinder.MultiEntry, list_traversal(sch))
2-element Array{String,1}:
 "E"
 "c"
```

and we see that `sch["E"]` and `sch["c"]` are indeed MultiEntry.
todo: přidat příklad s HUtils a 2 jsony, hledáním MultiEntry podle TypeIteratoru
 and take inspiration from HUtils section in Mill.kl -->
