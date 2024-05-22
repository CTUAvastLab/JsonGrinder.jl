@testset "NGramExtractor" begin
    e = NGramExtractor()
    common_extractor_tests(e, "Hello")
    common_extractor_tests(e, "")

    x1 = e("Hello")
    @test x1 isa ArrayNode{<:NGramMatrix, Nothing}
    @test x1.data.S == ["Hello"]
    @test mapreduce(e, catobs, ["Hello", "world"]).data.S == ["Hello", "world"]

    e = StableExtractor(e)
    x1 = e("Hello", store_input=Val(false))
    x2 = e("Hello", store_input=Val(true))
    @test x1 isa ArrayNode{<:NGramMatrix, Nothing}
    @test x2 isa ArrayNode{<:NGramMatrix, <:Vector}
    @test x1.data.S == ["Hello"]
    @test x1.data == x2.data
    @test x2.metadata == ["Hello"]
    @test mapreduce(e, catobs, ["Hello", "world"]).data.S == ["Hello", "world"]
    @test isequal(e(missing).data.S, [missing])
end

@testset "CategoricalExtractor" begin
    e = CategoricalExtractor(["a", "b"])
    common_extractor_tests(e, "a")
    common_extractor_tests(e, "z")

    @test e("a").data ≈ [1, 0, 0]
    @test e("a").data isa OneHotMatrix{UInt32, Vector{UInt32}}
    @test e("b").data ≈ [0, 1, 0]
    @test e("b").data isa OneHotMatrix{UInt32, Vector{UInt32}}
    @test e("z").data ≈ [0, 0, 1]
    @test e("z").data isa OneHotMatrix{UInt32, Vector{UInt32}}

    for e in map(StableExtractor, [
        CategoricalExtractor(["a", "b"]),
        CategoricalExtractor(LeafEntry(Dict("a"=> 1,"b"=> 1), 2))
    ])
        ea, eb, ez, en, em = e.(["a", "b", "z", nothing, missing])
        for x in (ea, eb, ez, en, em)
            @test x.data isa MaybeHotMatrix{Union{Missing, UInt32}, Union{Missing, Bool}}
        end
        @test ea.data ≈ [1, 0, 0]
        @test eb.data ≈ [0, 1, 0]
        @test ez.data ≈ [0, 0, 1]
        @test size(en.data) == (3, 0)
        @test size(em.data) == (3, 1)
        @test all(ismissing, em.data)
    end

    for e in map(StableExtractor, [
            CategoricalExtractor(LeafEntry{Number}(Dict(1 => 1, 2 => 1), 2))
            CategoricalExtractor(LeafEntry{Number}(Dict(1.0 => 1, 2.0 => 1), 2))
        ])
        @test e(1).data ≈ [1, 0, 0]
        @test e(2).data ≈ [0, 1, 0]
        @test e(4).data ≈ [0, 0, 1]
        @test e(1.).data ≈ [1, 0, 0]
        @test e(2.).data ≈ [0, 1, 0]
        @test e(4.).data ≈ [0, 0, 1]
    end

    sch = schema([1, 1.0, 1//1])
    e = CategoricalExtractor(sch)
    @test e(1) == e(1.0) == e(1//1)

    @testset "long strings trimming" begin
        max_string_length = JsonGrinder.max_string_length()
        JsonGrinder.max_string_length!(2)
        s1 = "foo"
        s2 = "foa"
        sch = JsonGrinder.schema([s1, s2])
        e = CategoricalExtractor(sch)

        @test e(s1) != e(s2)
        @test e(s1).data ≈ [1, 0, 0]
        @test e(s2).data ≈ [0, 1, 0]
        @test e("bar").data ≈ [0, 0, 1]
        JsonGrinder.max_string_length!(max_string_length)
    end
end

@testset "ScalarExtractor" begin
    e = ScalarExtractor(0, 1)
    common_extractor_tests(e, 1)

    @test e(5).data == [5.0;;]
    @test e(5).data isa Matrix{Float32}
    @test size(e(nothing)) == (1, 0)

    e = StableExtractor(e)
    @test e(5).data == [5.0;;]
    @test e(5).data isa Matrix{Union{Missing, Float32}}
    @test size(e(nothing)) == (1, 0)
    @test size(e(missing)) == (1, 1)
end
