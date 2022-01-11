using GraphViz

# generating schema of the workflow
g = GraphViz.Graph("""
digraph graphname {
   node [shape=box];
   label = "Basic workshow of Mill and JsonGrinder"
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
