## Implementing new extractor function 
Requirements on an extractor
1. The extractor should implemented as a *functor* (a callable structure) with an abstract supertype `JsonGrinder.AbstractExtractor.`  
2. The extractor has to return a subtype of `Mill.AbstractNode` with the correct number of samples. 
3. The extractor has to handle `missing`, typically by delegating this to appropriate Mill structures.
4. The extractor has to create a sample with zero observations (`extractempty`).

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
	x = Mill.emptyismissing ? missing : e.strings2mill(JsonGrider.extractempty)
	BagNode(x, [0:-1])
end
```

```julia
function (e::ExtractSentence)(::JsonGrinder.ExtractEmpty)
	x = e.strings2mill(JsonGrider.extractempty)
	BagNode(x, Mill.AlignedBags(Array{UnitRange{Int64},1}()))
end
```

And to make the function more error prone, we recommed to treat unknowns as missings
```julia
(e::ExtractSentence)(s) = e(missing)
```

## Handling empty bags
Mill.emptyismissing