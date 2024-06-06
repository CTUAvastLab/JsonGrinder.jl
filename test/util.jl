jss = map(JSON.parse, [
    """{ "a": [ { "a": 1 }, { "b": 2, "c":"oh" } ] }""",
    """{ "a": [ { "a": 1, "b": 3, "c":"hi" }, {"b": 2, "a": 1, "c": "Mark" } ] }""",
    """{ "a": [ { "a": 2, "b": 3 } ] }""",
    """{ "a": [], "d": [] }""",
    """{}"""])
s = schema(jss)
e = suggestextractor(s)

@testset "nnodes" begin
    @test nnodes(s) - 1 == nnodes(e) == 6
    @test nnodes(s.children[:a]) == nnodes(e.children[:a]) == 5
    @test nnodes(s.children[:a].items[:a]) == nnodes(e.children[:a].items[:a]) == 1
    @test nnodes(s.children[:d]) == 1
end

@testset "nleafs" begin
    @test nleafs(s) - 1 == nleafs(e) == 3
    @test nleafs(s.children[:a]) + nleafs(s.children[:d]) == nleafs(s)
    @test nleafs(e.children[:a]) == nleafs(e)
end

@testset "list_lens" begin
    ls = list_lens(s)
    all_nodes = NodeIterator(s) |> collect
    all_fields = vcat(all_nodes, [n.updated for n in all_nodes], [
        s.children,
        s.children[:a].lengths,
        s.children[:a].items.children,
        s.children[:a].items.children[:a].counts,
        s.children[:a].items.children[:b].counts,
        s.children[:a].items.children[:c].counts,
        s.children[:d].lengths
    ])

    @test all(l -> only(getall(s, l)) in all_fields, ls)
    @test all(n -> n in all_fields, [walk(s, t) for t in list_traversal(s)])

    ls = list_lens(e)
    all_nodes = NodeIterator(e) |> collect
    all_fields = vcat(all_nodes, [
        e.children[:a].items.children[:a].e.category_map,
        e.children[:a].items.children[:a].e,
        e.children[:a].items.children[:b].e.category_map,
        e.children[:a].items.children[:b].e,
        e.children[:a].items.children[:c].e.category_map,
        e.children[:a].items.children[:c].e,
    ])

    @test all(l -> only(getall(e, l)) in all_fields, ls)
    @test all(n -> n in all_fields, [walk(e, t) for t in list_traversal(e)])
end

@testset "find_lens" begin
    for t in list_traversal(s)
        ls = find_lens(s, s[t])
        @test all(l -> only(getall(s, l)) ≡ s[t], ls)
    end
    for t in list_traversal(e)
        ls = find_lens(e, e[t])
        @test all(l -> only(getall(e, l)) ≡ e[t], ls)
    end
end

@testset "code2lens & lens2code" begin
    for t in list_traversal(s)
        @test all(t .== vcat([lens2code(s, l) for l in code2lens(s, t)]...))
    end
    for t in list_traversal(e)
        @test all(t .≡ vcat([lens2code(e, l) for l in code2lens(e, t)]...))
    end
end
