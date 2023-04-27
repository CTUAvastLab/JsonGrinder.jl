# For developers and tweakers

## Implementing new extractor function
Requirements on an extractor
1. The extractor should be implemented as a *functor* (a callable structure) with an abstract supertype `JsonGrinder.AbstractExtractor.`  
2. The extractor has to return a subtype of `Mill.AbstractNode` with the correct number of samples.
3. The extractor has to handle `missing`, typically by delegating this to appropriate Mill structures, (see more details in [Handling empty bags](@ref)).
4. The extractor has to create a sample with zero observations when `extractempty` is passed as argument.

Let's demonstrate the creation of a new extractor on an extractor, that would represent the sentence as a bag of words.

```julia
using JsonGrinder, Mill
struct ExtractSentence{S} <: JsonGrinder.AbstractExtractor
	string2mill::S
end

ExtractSentence() = ExtractSentence(ExtractString())
```

Create a function for extracting strings
```julia
function (e::ExtractSentence)(s::String)
	ss = String.(split(s, " "))
	BagNode(e.string2mill(ss), [1:length(ss)])
end
```

Create a function for handling `missing`, which creates an
empty bag. An empty bag can contain either `missing` as its child, which
can create an explosion of types of extracted samples, or it can signal
to extractors underneath to extract a structure with zero observations.
```julia
function (e::ExtractSentence)(::Missing)
	x = Mill.emptyismissing() ? missing : e.strings2mill(JsonGrider.extractempty)
	BagNode(x, [0:-1])
end
```

```julia
function (e::ExtractSentence)(::JsonGrinder.ExtractEmpty)
	x = e.strings2mill(JsonGrider.extractempty)
	BagNode(x, Mill.AlignedBags(Array{UnitRange{Int64},1}()))
end
```

And to make the function more error prone, we recommend to treat unknowns as missings
```julia
(e::ExtractSentence)(s) = e(missing)
```

## Handling empty bags
Handling empty bags is (almost) straightforward by creating an empty bag, i.e. `BagNode(x, [0:-1])`. The fundamental question is, what the `x` should be? There are two philosophically different ways with different tradeoffs (both are supported).

1. `x = missing` is the natural approach, since empty bag does not have any instances and the inference (or backprop) on a sample does not need to descend into children. The drawback is that if one is processing a JSONs with sufficiently big schema, each `BagNode` can potentially create two types --- one with `missing` and the other with `x <: AbstractNode`. This will trigger a lot of compilation, which at the moment can take quite some time especially when calculating gradients with `Zygote`.
2. `x <: AbstractNode` with `numobs(x) = 0`. In other words, `x` would be the same type as it is if it contains instances, but it does not any observations. This has the advantage that all extracted samples will be of the same type and therefore there will be only single compilation for inference (and gradients). This is nice, but at the expense of less elegant code and probably small overhead caused by descending into children. This approach also needs a support from extractors, as creating an empty sample might be a bit tricky. As mentioned in preceding section, if an extractor wants its children to extract this special sample with zero observations, it asks them to extract a special singleton `JsonGrider.extractempty`. See above  `(e::ExtractSentence)(::Missing)` for an example.

The behavior is controlled by `Mill.emptyismissing!()` switch, where true means the first approach, false the second.

Every neural network created by `Mill` can by default always handle both versions, even though it was trained with the other one. Finally, `catobs` can handle these situations seamlessly as well.
