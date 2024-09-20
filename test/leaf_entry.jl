@testset "LeafEntry update!" begin
    e1 = LeafEntry(Real)
    e2 = LeafEntry(String)

    @test get(e1.counts, 1, 0) == get(e1.counts, 1.0, 0) == 0
    update!(e1, 1)
    @test haskey(e1.counts, 1)
    @test haskey(e1.counts, 1.0)
    @test e1.counts[1] == e1.counts[1.0] == 1
    update!(e1, 1.0)
    @test e1.counts[1] == e1.counts[1.0] == 2

    @test get(e2.counts, "", 0) == 0
    update!(e2, "")
    @test haskey(e2.counts, "")
    @test e2.counts[""] == 1

    @test get(e2.counts, "foo", 0) == 0
    update!(e2, "foo")
    @test haskey(e2.counts, "foo")
    @test e2.counts["foo"] == 1

    @test_throws InconsistentSchema update!(e1, "")
    @test !haskey(e1.counts, "")
    @test_throws InconsistentSchema update!(e2, 1)
    @test !haskey(e2.counts, 1)
    @test_throws InconsistentSchema update!(e2, missing)
    @test !haskey(e2.counts, missing)
    @test_throws NullValues update!(e1, nothing)
    @test !haskey(e1.counts, nothing)
end

@testset "LeafEntry various types" begin
    values = "a", split("a b")...

    e1 = LeafEntry(typeof(values[1]))
    e2 = LeafEntry(typeof(values[2]))
    update!(e1, values[1])
    update!(e1, values[2])
    update!(e1, values[3])
    update!(e2, values[3])
    update!(e2, values[2])
    update!(e2, values[1])

    @test e1 == e2
    @test e1.counts == Dict("a" => 2, "b" => 1)

    a, b, c = false, 1, 1.0

    e1 = LeafEntry(typeof(a))
    e2 = LeafEntry(typeof(b))
    e3 = LeafEntry(typeof(c))
    update!(e1, a)
    update!(e1, b)
    update!(e1, c)
    update!(e2, b)
    update!(e2, a)
    update!(e2, c)
    update!(e3, c)
    update!(e3, b)
    update!(e3, a)

    @test e1 == e2 == e3
    @test e1.counts == Dict(0 => 1, 1 => 2)
end

@testset "LeafEntry max_values" begin
    max_values = JsonGrinder.max_values()
    JsonGrinder.max_values!(3)

    e = LeafEntry(Real)
    for v in 1:3
        update!(e, v)
        @test e.updated == v
        @test length(e.counts) == v
        @test haskey(e.counts, v)
    end
    update!(e, 4)
    @test e.updated == 4
    @test length(e.counts) == 3
    @test !haskey(e.counts, 4)
    update!(e, 1)
    @test e.updated == 5
    @test length(e.counts) == 3
    @test e.counts[1] == 2

    e = LeafEntry(String)
    for v in 1:3
        update!(e, string(v))
        @test e.updated == v
        @test length(e.counts) == v
        @test haskey(e.counts, string(v))
    end
    update!(e, "4")
    @test e.updated == 4
    @test length(e.counts) == 3
    @test !haskey(e.counts, "4")
    update!(e, "1")
    @test e.updated == 5
    @test length(e.counts) == 3
    @test e.counts["1"] == 2

    JsonGrinder.max_values!(max_values)
end

@testset "LeafEntry max_string_len" begin
    max_string_len = JsonGrinder.max_string_length()
    JsonGrinder.max_string_length!(3)

    @test JsonGrinder.shorten_string("a") == "a"
    @test JsonGrinder.shorten_string("foo") == "foo"
    @test JsonGrinder.shorten_string("foo bar") == "foo_7_3773dea65156909838fa6c22825cafe090ff8030"
    @test JsonGrinder.shorten_string("barbaz") == "bar_6_32b1bf1853e6c39e4a1c3dae941ab7094ff1d293"

    e = LeafEntry(String)
    update!(e, "a")
    update!(e, "foo")
    update!(e, "foo bar")
    update!(e, "barbaz")
    @test e.updated == 4
    @test length(e.counts) == 4
    @test haskey(e.counts, "a")
    @test haskey(e.counts, "foo")
    @test !haskey(e.counts, "foo bar")
    @test !haskey(e.counts, "barbaz")

    JsonGrinder.max_string_length!(max_string_len)
end

@testset "DictEntry update!" begin
    e = DictEntry()

    @test length(e) == 0

    update!(e, Dict("k1" => 1))
    @test e.updated == 1
    @test haskey(e, :k1)
    @test !haskey(e, "k1")
    @test length(e) == 1

    update!(e, Dict("k2" => 2))
    @test e.updated == 2
    @test haskey(e, :k2)
    @test !haskey(e, "k2")
    @test length(e) == 2

    update!(e, Dict("k1" => 3))
    @test e.updated == 3
    @test length(e) == 2

    update!(e, Dict("k1" => 4, "k2" => 5, "k3" => 6))
    @test e.updated == 4
    @test length(e) == 3
end

@testset "ArrayEntry update!" begin
    e = ArrayEntry()

    @test isnothing(e.items)
    update!(e, [])
    @test isnothing(e.items)
    update!(e, [1, 2, 3])
    @test !isnothing(e.items)
    update!(e, [])
    @test !isnothing(e.items)
    update!(e, [1])
    @test e.updated == 4
    @test e.items.updated == 4
end
