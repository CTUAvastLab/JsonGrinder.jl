using GraphViz

# generating schema of the workflow

g = GraphViz.Graph("""
digraph graphname {
    bgcolor="transparent"
    node [shape=box]
    label = "Basic workflow of Mill.jl and JsonGrinder.jl"
    a  [label="step 1\ncreate schema"]
    b  [label="step 2\ncreate extractor from schema"]
    c  [label="step 3\ncreate model from schema and extractor"]
    d  [label="step 4\nprepare training data using the extractor"]
    e  [label="step 5\ntrain the model"]
    a -> b -> c -> d -> e;
}
""");
GraphViz.layout!(g, engine="dot")
open(joinpath(@__DIR__, "src", "assets", "workflow.svg"), "w+") do io
    GraphViz.render(io, g)
end

white = "\"#F2F2F2\""
g = GraphViz.Graph("""
digraph graphname {
    bgcolor="transparent"
    node [shape=box]
    label = "Basic workflow of Mill.jl and JsonGrinder.jl"
    fontcolor = $white
    a  [label="step 1\ncreate schema", color=$white, fontcolor=$white]
    b  [label="step 2\ncreate extractor from schema", color=$white, fontcolor=$white]
    c  [label="step 3\ncreate model from schema and extractor", color=$white, fontcolor=$white]
    d  [label="step 4\nprepare training data using the extractor", color=$white, fontcolor=$white]
    e  [label="step 5\ntrain the model", color=$white, fontcolor=$white]
    a -> b -> c -> d -> e[color=$white];
}
""");
GraphViz.layout!(g, engine="dot")
open(joinpath(@__DIR__, "src", "assets", "workflow-dark.svg"), "w+") do io
    GraphViz.render(io, g)
end
