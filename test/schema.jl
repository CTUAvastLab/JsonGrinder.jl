function test_permutations_merging(jss)
    @test map(schema, first(permutations(jss), 50)) |> allequal

    sch = schema(jss)

    @test merge([schema([js]) for js in jss]...) == sch
    @test merge([schema([js]) for js in reverse(jss)]...) == sch
    @test merge(schema(jss[1:2:end]), schema(jss[2:2:end])) == sch
    @test merge(schema(jss)) == sch

    @test merge!(schema(jss)) == sch
    for i in eachindex(jss)
        s = schema(jss[i:i])
        @test merge!(s, schema(vcat(jss[1:i-1], jss[i+1:end]))) == sch
        if i ∈ 2:length(jss) - 1
            s = schema(jss[i:i])
            @test merge!(s, schema(jss[1:i-1]), schema(jss[i+1:end])) == sch
        end
        s = schema(jss[i:i])
        @test merge!(s, [schema(jss[j:j]) for j in vcat(1:i-1, i+1:length(jss))]...) == sch
        s = schema(jss[i:i])
        for j in eachindex(jss)
            i != j && merge!(s, schema(jss[j:j]))
        end
        @test s == sch
    end
end

@testset "basic" begin
    jss = map(JSON.parse, [
        """ {"a": 4, "c": {"a": {"a": [2, 3], "b": [5, 6]}}} """,
        """ {"a": 4, "b": {"a": [1, 2, 3], "b": 1}} """,
        """ {"a": 4, "b": {}} """,
        """ {"b": {}} """,
        """ {} """
    ])
    push!(jss, JSON.parse("""
        {"a": 4, "b": {"a": [1, 2, 3], "b": 1}, "c": {"a": {"a": [1, 2, 3], "b": [4, 5, 6]}}}
    """, inttype=Float64))

    sch = schema(jss)
    @test sch[:a].counts == Dict(4 => 4)
    @test sch[:a].updated == 4
    @test sch[:b].updated == 4
    @test sch[:b][:a].updated == 2
    @test sch[:b][:a].lengths == Dict(3 => 2)
    @test sch[:b][:a].items.counts == Dict(1 => 2, 2 => 2, 3 => 2)
    @test sch[:b][:a].items.updated == 6
    @test sch[:b][:b].counts == Dict(1 => 2)
    @test sch[:b][:b].updated == 2
    @test sch[:c].updated == 2
    @test sch[:c][:a].updated == 2
    @test sch[:c][:a][:a].updated == 2
    @test sch[:c][:a][:a].lengths == Dict(2 => 1, 3 => 1)
    @test sch[:c][:a][:a].items.counts == Dict(1 => 1, 2 => 2, 3 => 2)
    @test sch[:c][:a][:a].items.updated == 5
    @test sch[:c][:a][:b].updated == 2
    @test sch[:c][:a][:b].lengths == Dict(2 => 1, 3 => 1)
    @test sch[:c][:a][:b].items.counts == Dict(4 => 1, 5 => 2, 6 => 2)
    @test sch[:c][:a][:b].items.updated == 5
    @test keys(sch[:a].counts) |> collect == [4]

    test_permutations_merging(jss)
end

@testset "top level" begin
    sch = schema([1, 1.0, true])
    @test sch isa LeafEntry
    @test sch.updated == 3

    sch = schema(["", "foo", "bar", "baz"])
    @test sch isa LeafEntry
    @test sch.updated == 4

    sch = schema([[], [], [1, 2, 3], [3], []])
    @test sch isa ArrayEntry
    @test sch.updated == 5
    @test sch.items isa LeafEntry
    @test sch.items.updated == 4
end

@testset "raw JSONs" begin
    jss = [
        """ {"a": 1} """,
        """ {"a": 2} """,
        """ {"a": 3} """
    ]

    sch = schema(JSON.parse, jss)
    @test sch[:a].updated == 3
end

@testset "Equals and hash test" begin
    j1 = JSON.parse(""" {"a": []} """)
    j2 = JSON.parse(""" {"a": [{"a": 1}, {"b": 2}]} """)
    j3 = JSON.parse(""" {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}]} """)
    j4 = JSON.parse(""" {"a": [{"a": 2, "b": 3}]} """)

    sch1 = JsonGrinder.DictEntry()
    sch2a = schema([j1, j2, j3, j4])
    sch2b = schema([j4, j3, j2, j1])
    sch3 = schema([j1, j2, j3])

    @test sch2b == sch2a
    @test sch2b != sch3
    @test sch2b != sch1
    @test sch3 != sch1

    @test hash(sch2b) == hash(sch2a)
    @test hash(sch2b) != hash(sch3)
    @test hash(sch2b) != hash(sch1)
    @test hash(sch3) != hash(sch1)
end

@testset "Empty arrays" begin
    j1 = JSON.parse(""" {"a": []} """)
    j2 = JSON.parse(""" {"a": [{"a": 1}, {"b": 2}]} """)
    j3 = JSON.parse(""" {"a": [{"a": 1,"b": 3}, {"b": 2,"a" : 1}]} """)
    j4 = JSON.parse(""" {"a": [{"a": 2,"b": 3}]} """)
    j5 = JSON.parse(""" {"a": [{"a": 1}, {"b": 2}], "b": []}""")
    j6 = JSON.parse(""" {"a": [{"a": 1,"b": 3}, {"b": 2,"a": 1}], "b": []}""")

    sch = schema([j1])
    @test sch.updated == 1
    @test keys(sch) == Set([:a])

    sch = schema([j1, j2])
    @test sch.updated == 2
    @test sch[:a].updated == 2
    @test !haskey(sch, :b)

    test_permutations_merging([j1, j2, j3, j4, j5, j6])
end

@testset "Consistency 1" begin
    jss = map(JSON.parse, [
        """ {"a": [{"a": 1}, {"b": 2}]} """,
        """ {"a": [{"a": 1, "b": 3},{"b": 2, "a": 1}]} """,
        """ {"a": [{"a": 2, "b": 3}]} """,
        """ {"a": []} """,
        """ {} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}], "b": 1} """
    ])

    test_permutations_merging(jss)
end

@testset "Consistency 2" begin
    jss = map(JSON.parse, [
        """ {} """,
        """ { "a": [] } """,
        """ { "a": [1, 2] } """,
        """ { "b": {} } """,
        """ { "b": { "c": "foo" } } """,
    ])

    test_permutations_merging(jss)
end

@testset "Consistency 3" begin
    jss = map(JSON.parse, [
        """{"a": [{"a": 1}, {"b": 2}], "b": []}""",
        """{"a": [{"a": 3}, {"b": 4}], "b": []}""",
        """{"a": [{"a": 1}, {"b": 3}], "b": []}""",
        """{"a": [{"a": 2}, {"b": 4}], "b": [1]}"""
    ])

    test_permutations_merging(jss)
end

@testset "Consistency 4" begin
    jss = map(JSON.parse, [
        """ {"a": [{"a": 1}, {"b": 2}]} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}]} """,
        """ {"a": [{"a": 2, "b": 3}]} """,
        """ {"a": []} """,
        """ {} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}], "b": 1} """,
        """ {"a": [{"a": 4, "b": 5}, {"b": 6, "a": 7}], "b": 2} """,
        """ {"a": [{"a": 9, "b": 10}, {"b": 11, "a": 12}], "b": 2} """,
    ])

    test_permutations_merging(jss)
end

@testset "Consistency (number types)" begin
    jss = map(JSON.parse, [
        """ {"a": 1} """,
        """ {"a": 2} """,
        """ {"a": 3.3} """,
        """ {"a": 4.4} """,
        """ {"a": false} """,
    ])

    test_permutations_merging(jss)
end

function test_inconsistent(jss)
    @test_throws InconsistentSchema schema(jss)
    @test_throws InconsistentSchema merge([schema([js]) for js in jss]...)
    for js1 in jss
        for js2 in jss
            js1 ≡ js2 && continue
            @test_throws InconsistentSchema merge(schema([js1]), schema([js2]))
            sch = schema([js1])
            @test_throws InconsistentSchema merge!(sch, schema([js2]))
            sch = schema([js1])
            @test_throws InconsistentSchema update!(sch, js2)
        end
    end
end

@testset "Inconsistent 1" begin
    jss = map(JSON.parse, [
        """ {"a": 4} """,
        """ {"a": "foo"} """
    ])
    test_inconsistent(jss)
end

@testset "Inconsistent 2" begin
    jss = map(JSON.parse, [
        """ [1] """,
        """ ["foo"] """,
        """ "foo" """
    ])
    test_inconsistent(jss)
end

@testset "Inconsistent 3" begin
    jss = map(JSON.parse, [
        """ {"a": 4} """,
        """ {"a": { "a": "foo", "b":[5, 6]}} """,
        """ {"a": [1, 2, 3, 4]} """
    ])
    test_inconsistent(jss)

    jss = [Dict("a" => [j["a"]]) for j in jss]
    test_inconsistent(jss)
end

@testset "Inconsistent 4" begin
    jss = map(JSON.parse, [
        """ {"a": [{"a": 1}, {"b": 2}], "b": []} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}], "b": {}} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}], "b": 1} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}], "b": "string"} """
    ])

    test_inconsistent(jss)
end

@testset "Inconsistent 5" begin
    jss = map(JSON.parse, [
    """ {"a": "4", "b": "2"} """,
    """ {"a": 7, "b": "3"} """,
    """ {"a": 4, "b": 3} """,
    """ {"a": "11", "b": 3} """,
    ])

    test_inconsistent(jss)
end

@testset "Schema merging respects max_keys" begin
    jss = map(JSON.parse, [
        """ {"a": [{"a": 1}, {"b": 2}]} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}]} """,
        """ {"a": [{"a": 2, "b": 3}]} """,
        """ {"a": []} """,
        """ {} """,
        """ {"a": [{"a": 1, "b": 3}, {"b": 2, "a": 1}], "b": 1} """,
        """ {"a": [{"a": 4, "b": 5}, {"b": 6, "a": 7}], "b": 3} """,
        """ {"a": [{"a": 9, "b": 10}, {"b": 11, "a": 12}], "b": 4} """,
        """ {"a": [{"a": 4, "b": 3}, {"b": 2, "a": 2}], "b": 5} """,
        """ {"a": [{"a": 11, "b": 12}, {"b": 13, "a": 14}], "b": 6} """,
        """ {"a": [{"a": 7, "b": 5}, {"b": 6, "a": 6}], "b": 7} """,
    ])

    # no need to test `merge` and `merge!` results below if this passes
    test_permutations_merging(jss)

    mk = JsonGrinder.max_keys()
    for i in 1:10
        JsonGrinder.max_keys!(i)
        sch = schema(jss)
        @test length(sch[:a].items[:a].counts) ≤ i
        @test length(sch[:a].items[:b].counts) ≤ i
        @test length(sch[:b].counts) ≤ i
    end

    JsonGrinder.max_keys!(mk)
end

@testset "representative_example" begin
    sch = DictEntry(Dict(
        :a => ArrayEntry(
            DictEntry(Dict(
                :a => LeafEntry(Dict(1 => 4, 2 => 1), 5),
                :b => LeafEntry(Dict(1 => 1, 2 => 2, 3 => 2), 5),
            ), 5), Dict(0 => 1, 1 => 1, 2 => 2), 4),
        :b => LeafEntry(Dict(1 => 2, 2 => 2), 4)), 4)

    @test JsonGrinder.representative_example(sch) == Dict(
        "a" => [Dict("a" => 2, "b" => 2)], "b" => 2)

    sch = DictEntry(Dict(
        :a => ArrayEntry(
            DictEntry(Dict(
                :a => LeafEntry(Dict(1 => 3, 2 => 1), 4),
                :b => LeafEntry(Dict(2 => 2, 3 => 2), 4),
            ), 5), Dict(0 => 1, 1 => 1, 2 => 2), 4),
        :b => LeafEntry(Dict(1 => 2, 2 => 2), 4)), 4)

    @test JsonGrinder.representative_example(sch) == Dict(
        "a" => [Dict("a" => 2, "b" => 2)], "b" => 2)
end
