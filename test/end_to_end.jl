function test_with_model(jss)
    sch = @test_nowarn schema(jss)
    e = @test_nowarn suggestextractor(sch)
    test_with_model(jss, sch, e)
end

function test_with_model(jss, sch, e)
    if !isnothing(e)
        dss = @test_nowarn e.(jss)
        m = @test_nowarn reflectinmodel(sch, e)
        @test_nowarn m.(dss)
        @test_nowarn m(reduce(catobs, dss))
    end
end

@testset "Stability heuristic" begin
    e = map(JSON.parse, [
        """ { "a": { "b" : [1, 2, 3], "c": "foo" } } """
        """ { "a": { "b" : [], "c": "bar" } } """
    ]) |> schema |> suggestextractor
    @test !(e[:a][:b].items isa StableExtractor)
    @test !(e[:a][:c] isa StableExtractor)

    e = map(JSON.parse, [
        """ { "a": { "b" : [1, 2, 3], "c": "foo" } } """
        """ { "a": { "b" : [] } } """
    ]) |> schema |> suggestextractor
    @test !(e[:a][:b].items isa StableExtractor)
    @test e[:a][:c] isa StableExtractor

    e = map(JSON.parse, [
        """ { "a": { "b" : [1, 2, 3], "c": "foo" } } """
        """ { "a": { "c" : "bar" } } """
    ]) |> schema |> suggestextractor
    @test e[:a][:b].items isa StableExtractor
    @test !(e[:a][:c] isa StableExtractor)

    e = map(JSON.parse, [
        """ { "a": { "b" : [1, 2, 3], "c": "foo" } } """
        """ { } """
    ]) |> schema |> suggestextractor
    @test e[:a][:b].items isa StableExtractor
    @test e[:a][:c] isa StableExtractor

    e = map(JSON.parse, [
        """ [ { "a": 1 } ] """,
        """ [ {} ] """,
    ]) |> schema |> suggestextractor
    @test e.items[:a] isa StableExtractor

    e = map(JSON.parse, [
        """ [ { "a": 1 } ] """,
        """ [ ] """,
    ]) |> schema |> suggestextractor
    @test !(e.items[:a] isa StableExtractor)
end

@testset "Leaving out empty structures" begin
    @test suggestextractor(schema([JSON.parse("{}")])) |> isnothing
    @test suggestextractor(schema([JSON.parse("[]")])) |> isnothing
    @test suggestextractor(schema([JSON.parse("[[]]")])) |> isnothing
    @test suggestextractor(schema([JSON.parse("[{}, {}]")])) |> isnothing

    jss = map(JSON.parse, [
        """ { "a": {}, "c": {} } """
        """ { "a": {} } """
        """ { "c": {} } """
    ])
    @test suggestextractor(schema(jss)) |> isnothing

    jss = map(JSON.parse, [
        """ { "a": [], "c": {} } """
        """ { "a": [] } """
        """ { "c": { "d": [[], []] } } """
    ])
    @test suggestextractor(schema(jss)) |> isnothing

    jss = map(JSON.parse, [
        """ { "a": { "b": [1] }, "c": {} } """
        """ { "a": {} } """
        """ { "c": {} } """
    ])
    e = suggestextractor(schema(jss))
    @test haskey(e, :a)
    @test !haskey(e, :c)
end

@testset "suggestextractor kwargs" begin
    @testset "min_occurences" begin
        sch = map(JSON.parse, [
            """ { "a": 1, "b": [], "d": {} } """,
            """ { "b": [], "d": {} } """,
            """ { "a": 1, "b": [ { "c": 1 } ], "d": { "e": [] } } """,
        ]) |> schema

        e = suggestextractor(sch; min_occurences=1)
        @test haskey(e, :a)
        @test haskey(e, :b)
        @test haskey(e[:b].items, :c)
        @test !haskey(e, :d)

        e = suggestextractor(sch; min_occurences=2)
        @test haskey(e, :a)
        @test !haskey(e, :b)
        @test !haskey(e, :d)

        @test suggestextractor(sch; min_occurences=3) |> isnothing
    end

    @testset "all_stable" begin
        sch = map(JSON.parse, [
            """ { "a": 1, "b": []} """,
            """ { "a": 1, "b": []} """,
            """ { "a": 1, "b": [ { "c": 1 } ]} """,
        ]) |> schema

        e = suggestextractor(sch)
        @test all(l -> !(l isa StableExtractor), LeafIterator(e))
        @test stabilizeextractor(e) == suggestextractor(sch; all_stable=true)
        @test all(l -> l isa StableExtractor, LeafIterator(suggestextractor(sch; all_stable=true)))
    end

    @testset "categorical_limit" begin
        sch = map(JSON.parse, [
            """ { "a": [1, 2], "b": [1, 2] } """,
            """ { "a": [3], "b": [2] } """,
        ]) |> schema

        e = suggestextractor(sch; categorical_limit=0)
        @test all(l -> l isa ScalarExtractor, LeafIterator(e))
        e = suggestextractor(sch; categorical_limit=10)
        @test all(l -> l isa CategoricalExtractor, LeafIterator(e))
        e = suggestextractor(sch; categorical_limit=2)
        @test e[:a].items isa ScalarExtractor
        @test e[:b].items isa CategoricalExtractor
    end

    @testset "ngram_params" begin
        sch = [JSON.parse(""" ["foo", "bar", "baz"] """)] |> schema

        e = suggestextractor(sch; categorical_limit=0, ngram_params=(n=1, b=2, m=3))
        @test e.items.n == 1
        @test e.items.b == 2
        @test e.items.m == 3

        e = suggestextractor(sch; categorical_limit=0, ngram_params=(n=1, m=3))
        @test e.items.n == 1
        @test e.items.b == 256
        @test e.items.m == 3
    end
end

@testset "E2E 1: Nested Dicts" begin
    jss = map(JSON.parse, [
        """ { "a": { "b": 1 }, "c": { "d": "foo" } } """,
        """ { "a": { "b": 2 } } """,
        """ { "a": { "b": 3 }, "c": {} } """
    ])
    sch = schema(jss)
    e = suggestextractor(sch)
    test_with_model(jss, sch, e)

    a1 = e(jss[1])
    a2 = e(jss[2])
    a3 = e(jss[3])

    @test numobs(a1) == numobs(a2) == numobs(a3) == 1

    for a in [a1, a2, a3]
        @test a[:a][:b].data isa OneHotMatrix
        @test a[:c][:d].data isa MaybeHotMatrix
    end

    @test isequal(
        e(JSON.parse("""{ "a": { "b": 1 } }""")),
        e(JSON.parse("""{ "a": { "b": 1 }, "c": {} }"""))
    )
end

@testset "E2E 2: Dict x Array" begin
    jss = map(JSON.parse, [
        """ { "a": [1, 2, 3], "b": [4, 5, 6] } """,
        """ { "a": [1, 2, 3] } """,
        """ { "b": [] } """
    ])
    sch = schema(jss)
    e = suggestextractor(sch)
    test_with_model(jss, sch, e)

    a1 = e(jss[1])
    a2 = e(jss[2])
    a3 = e(jss[3])

    @test numobs(a1) == numobs(a2) == numobs(a3) == 1

    @test a1[:a].bags.bags == [1:3]
    @test a2[:a].bags.bags == [1:3]
    @test a3[:a].bags.bags == [0:-1]
    @test a1[:b].bags.bags == [1:3]
    @test a2[:b].bags.bags == [0:-1]
    @test a3[:b].bags.bags == [0:-1]
    for a in [a1, a2, a3], k in [:a, :b]
        @test a[k].data.data isa MaybeHotMatrix
    end

    @test e(JSON.parse("{}")) ==
          e(JSON.parse(""" { "a": [] } """)) ==
          e(JSON.parse(""" { "b": [] } """)) ==
          e(JSON.parse(""" { "a": [], "b": [] } """))
end

@testset "E2E 3: Nested Arrays" begin
    jss = map(JSON.parse, [
        """ [[1, 2], [3, 4, 5]] """,
        """ [[], [3, 4, 5]] """,
        """ [[9]] """,
        """ [] """
    ])
    sch = schema(jss)
    e = suggestextractor(sch)
    test_with_model(jss, sch, e)

    a1 = e(jss[1])
    a2 = e(jss[2])
    a3 = e(jss[3])
    a4 = e(jss[4])

    @test numobs(a1) == numobs(a2) == numobs(a3) == numobs(a4) == 1
    @test numobs(a1.data) == numobs(a2.data) == 2
    @test numobs(a3.data) == 1
    @test numobs(a4.data) == 0
    @test numobs(a1.data.data) == 5
    @test numobs(a2.data.data) == 3
    @test numobs(a3.data.data) == 1
    @test numobs(a4.data.data) == 0

    for a in [a1, a2, a3, a4]
        @test a.data.data.data isa OneHotMatrix
    end
end

@testset "E2E 4: Array x Dict" begin
    jss = map(JSON.parse, [
        """ [ { "a": "foo" }, { "a": "bar" } ] """,
        """ [ { "a": "baz" } ] """,
        """ [ { } ] """,
        """ [ ] """
    ])
    sch = schema(jss)
    e = suggestextractor(sch)
    test_with_model(jss, sch, e)

    a1 = e(jss[1])
    a2 = e(jss[2])
    a3 = e(jss[3])
    a4 = e(jss[4])

    @test numobs(a1) == numobs(a2) == numobs(a3) == 1
    @test numobs(a1.data) == 2
    @test numobs(a2.data) == 1
    @test numobs(a3.data) == 1
    @test numobs(a4.data) == 0

    for a in [a1, a2, a3, a4]
        @test a.data[:a].data isa MaybeHotMatrix
    end
end

@testset "E2E 5: Dict x Array x Dict" begin
    jss = map(JSON.parse, [
        """ { "a": [ { "b": "foo"}, { "b": "bar" } ] } """,
        """ { "a": [ {}, { "b": "baz" } ] } """,
        """ { "a": [] } """
    ])
    sch = schema(jss)
    e = suggestextractor(sch)
    test_with_model(jss, sch, e)

    a1 = e(jss[1])
    a2 = e(jss[2])
    a3 = e(jss[3])

    @test numobs(a1) == numobs(a2) == numobs(a3) == 1
    @test numobs(a1[:a]) == numobs(a2[:a]) == numobs(a3[:a]) == 1
    @test numobs(a1[:a].data) == numobs(a2[:a].data) == 2
    @test numobs(a3[:a].data) == 0

    for a in [a1, a2, a3]
        @test a[:a].data.data[:b].data isa MaybeHotMatrix
    end

    @test e(JSON.parse("""{ }""")) == e(JSON.parse(""" { "a": [] } """))
    @test e(JSON.parse(""" { "a": [] } """)) != e(JSON.parse(""" { "a": [ {} ] } """)) 
end

generate(::Type{String}; stable=false) = randstring(3)
generate(::Type{Real}; stable=false) = rand([Int, Float64, Float32])(rand(1:5))
function generate(s::Vector; stable=false)
    isempty(s) && return []
    [generate(only(s); stable) for _ in 1:rand([0, 1, 2, rand(3:5)])]
end
function generate(s::Dict; stable=false)
    ks = shuffle(collect(keys(s)))
    if !stable
        ks = ks[1:rand(0:length(s))]
    end
    Dict(k => generate(s[k]; stable) for k in ks)
end

function random_schema(d)
    d == 0 && return rand([fill(String, 10)..., fill(Real, 10)..., Dict(), []])
    if rand() < 0.5
        return [random_schema(d - 1)]
    else
        return Dict(string(k) => random_schema(d - 1) for k in shuffle('a':'z')[1:rand(1:4)])
    end
end

@testset "Random $(stable ? "stable" : "unstable") schema, depth $d" for d in 1:3, stable in [true, false]
    for _ in 1:10
        _s = random_schema(d)
        xs1 = [generate(_s; stable) for _ in 1:10]
        xs2 = @test_nowarn [JsonGrinder.representative_example(schema(xs1))]
        foreach(test_with_model, (xs1, xs2))
    end
end
