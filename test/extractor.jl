function common_extractor_tests(e::Extractor, v; test_stability=true)
    @test numobs(e(v)) == 1
    @test all(isnothing, Mill.metadata.(NodeIterator(e(v, store_input=Val(false)))))
    @test e(v, store_input=Val(true)).metadata == [v]
    @test dropmeta(e(v, store_input=Val(true))) == e(v)
    test_stability && @test_nowarn @inferred e(v)
    test_stability && @test_nowarn @inferred extract(e, [v])

    for store_input in [true, false] .|> Val
        @test isequal(e(v; store_input), extract(e, [v]; store_input))
        @test isequal(catobs(e(v; store_input), e(v; store_input)), extract(e, [v, v]; store_input))
    end

    # this is not needed for batch version, we test only single version
    @test numobs(e(nothing)) == 0
    @test e(nothing).metadata |> isnothing
    @test dropmeta(e(nothing)) == e(nothing)
    test_stability && @test_nowarn @inferred e(nothing)

    if e isa LeafExtractor && !(e isa StableExtractor)
        @test_throws IncompatibleExtractor e(missing)
        @test_throws IncompatibleExtractor extract(e, [missing])
    end
    e = stabilizeextractor(e)
    @test numobs(e(missing)) == 1
    @test e(missing, store_input=Val(false)).metadata |> isnothing
    @test isequal(e(missing, store_input=Val(true)).metadata, [missing])
    for x in [v, missing]
        @test isequal(dropmeta(e(x, store_input=Val(true))), e(x))
        @test all(n -> eltype(n.data) <: Union{Missing, T} where T, LeafIterator(e(x)))
        test_stability && @test_nowarn @inferred e(x)
        test_stability && @test_nowarn @inferred extract(e, [v])
    end
end

both_extractions(e) = (
    (v; kwargs...) -> e(v; kwargs...),
    (v; kwargs...) -> extract(e, [v]; kwargs...)
)

@testset "NGramExtractor" begin
    e = NGramExtractor()
    common_extractor_tests(e, "Hello")
    common_extractor_tests(e, "")

    for ext in both_extractions(e)
        x1 = ext("Hello")
        @test x1 isa ArrayNode{<:NGramMatrix, Nothing}
        @test x1.data.S == ["Hello"]
        @test mapreduce(e, catobs, ["Hello", "world"]).data.S == ["Hello", "world"]
    end

    for ext in StableExtractor(e) |> both_extractions
        x1 = ext("Hello"; store_input=Val(false))
        x2 = ext("Hello"; store_input=Val(true))
        @test x1 isa ArrayNode{<:NGramMatrix, Nothing}
        @test x2 isa ArrayNode{<:NGramMatrix, <:Vector}
        @test x1.data.S == ["Hello"]
        @test x1.data == x2.data
        @test x2.metadata == ["Hello"]
        @test mapreduce(e, catobs, ["Hello", "world"]).data.S == ["Hello", "world"]
        @test isequal(ext(missing).data.S, [missing])
    end
end

@testset "CategoricalExtractor" begin
    e = CategoricalExtractor(["a", "b"])
    common_extractor_tests(e, "a")
    common_extractor_tests(e, "z")

    for ext in both_extractions(e)
        @test ext("a").data ≈ [1, 0, 0]
        @test ext("a").data isa OneHotMatrix
        @test ext("b").data ≈ [0, 1, 0]
        @test ext("b").data isa OneHotMatrix
        @test ext("z").data ≈ [0, 0, 1]
        @test ext("z").data isa OneHotMatrix
    end

    en = e(nothing)
    @test en.data isa OneHotMatrix
    @test size(en.data) == (3, 0)
    en = StableExtractor(e)(nothing)
    @test en.data isa MaybeHotMatrix
    @test size(en.data) == (3, 0)

    for e in map(StableExtractor, [
        CategoricalExtractor(["a", "b"]),
        CategoricalExtractor(LeafEntry(Dict("a"=> 1,"b"=> 1), 2))
    ]), ext in both_extractions(e)
        ea, eb, ez, em = ext.(["a", "b", "z", missing])
        for x in (ea, eb, ez, em)
            @test x.data isa MaybeHotMatrix
        end
        @test ea.data ≈ [1, 0, 0]
        @test eb.data ≈ [0, 1, 0]
        @test ez.data ≈ [0, 0, 1]
        @test size(em.data) == (3, 1)
        @test all(ismissing, em.data)
    end

    for e in map(StableExtractor, [
            CategoricalExtractor(LeafEntry{Number}(Dict(1 => 1, 2 => 1), 2))
            CategoricalExtractor(LeafEntry{Number}(Dict(1.0 => 1, 2.0 => 1), 2))
        ]), ext in both_extractions(e)
        @test ext(1).data ≈ [1, 0, 0]
        @test ext(2).data ≈ [0, 1, 0]
        @test ext(4).data ≈ [0, 0, 1]
        @test ext(1.).data ≈ [1, 0, 0]
        @test ext(2.).data ≈ [0, 1, 0]
        @test ext(4.).data ≈ [0, 0, 1]
    end

    for ext in CategoricalExtractor(schema([1, 1.0, 1//1])) |> both_extractions
        @test ext(1) == ext(1.0) == ext(1//1)
    end

    @testset "long strings trimming" begin
        max_string_length = JsonGrinder.max_string_length()
        JsonGrinder.max_string_length!(2)
        s1 = "foo"
        s2 = "foa"

        for ext in CategoricalExtractor(schema([s1, s2])) |> both_extractions
            @test ext(s1) != ext(s2)
            @test ext(s1).data ≈ [1, 0, 0]
            @test ext(s2).data ≈ [0, 1, 0]
            @test ext("bar").data ≈ [0, 0, 1]
        end
        JsonGrinder.max_string_length!(max_string_length)
    end
end

@testset "ScalarExtractor" begin
    e = ScalarExtractor(0, 1)
    common_extractor_tests(e, 1)

    @test size(e(nothing)) == (1, 0)
    for ext in both_extractions(e)
        @test ext(5).data == [5.0;;]
        @test ext(5).data isa Matrix{Float32}
    end

    e = StableExtractor(e)

    @test size(e(nothing)) == (1, 0)
    for ext in both_extractions(e)
        @test ext(5).data == [5.0;;]
        @test ext(5).data isa Matrix{Union{Missing, Float32}}
        @test size(ext(missing)) == (1, 1)
    end
end

@testset "ArrayExtractor" begin
    for (inner_e, js) in zip(
        [ CategoricalExtractor(2:4), ScalarExtractor(), NGramExtractor() ],
        [ [2, 3, 4], [2, 3, 4], ["foo", "bar", "baz"] ])
        e = ArrayExtractor(inner_e)
        common_extractor_tests(e, js)
        common_extractor_tests(e, empty(js))

        x = e(nothing)
        @test x.bags == AlignedBags(Int[])
        @test isempty(x.data.data)
        @test numobs(x.data) == 0
        @test numobs(x.data.data) == 0

        for ext in both_extractions(e)
            x1 = ext(js)
            x2 = ext(js, store_input=Val(true))
            x3 = ext(empty(js))
            x4 = ext(empty(js))
            x5 = ext(missing)
            x6 = ext(missing, store_input=Val(true))

            @test x1.bags == x2.bags == AlignedBags([1:3])
            @test x3.bags == x4.bags == x5.bags == x6.bags == AlignedBags([0:-1])

            @test dropmeta(x1) == dropmeta(x2)
            @test dropmeta(x3) == dropmeta(x4)
            @test isequal(dropmeta(x5), dropmeta(x6))

            @test x1.data == mapreduce(e.items, catobs, js)
            @test x2.data == mapreduce(x -> e.items(x; store_input=Val(true)), catobs, js)
            for x in [x3, x4, x5, x6]
                @test isempty(x.data.data)
                @test numobs(x.data) == 0
                @test numobs(x.data.data) == 0
            end
        end
    end
end

@testset "DictExtractor" begin
    e = DictExtractor((
        a = ScalarExtractor(2, 3),
        b = CategoricalExtractor(1:10),
        c = ArrayExtractor(ScalarExtractor(2, 3))
    ))
    jss = [
        Dict("a" => 5, "b" => 7, "c" => Int[1, 2, 3, 4]),
        Dict("a" => 5, "b" => 7),
        Dict("a" => 5, "c" => Int[1, 2, 3, 4])
    ]
    common_extractor_tests(e, jss[1]; test_stability=false)
    common_extractor_tests(e, jss[2]; test_stability=false)
    @test_throws IncompatibleExtractor e(jss[3])
    @test_throws IncompatibleExtractor extract(e, jss[3:3])
    e = stabilizeextractor(e)
    common_extractor_tests(e, jss[2]; test_stability=false)

    x = e(nothing)
    @test isequal(x, ProductNode(; (k => e.children[k](nothing) for k in [:a, :b, :c])...))

    for ext in both_extractions(e)
        x1 = ext(jss[1])
        x2 = ext(jss[1], store_input=Val(true))
        x3 = ext(jss[2])
        x4 = ext(jss[2], store_input=Val(true))
        x5 = ext(jss[3])
        x6 = ext(jss[3], store_input=Val(true))

        @test isequal(reduce(catobs, ext.(jss)), reduce(catobs, [x1, x3, x5]))
        @test isequal(reduce(catobs, ext.(jss; store_input=Val(true))), reduce(catobs, [x2, x4, x6]))

        for (x, i, si) in zip(
            [x1, x2, x3, x4, x5, x6],
            [1, 1, 2, 2, 3, 3],
            [false, true, false, true, false, true]
        )
            js = jss[i]
            for k in keys(js)
                @test isequal(x.data[Symbol(k)], e[Symbol(k)](js[k]; store_input=Val(si)))
            end
        end

        @test x1[:a] == x3[:a] == x5[:a]
        @test x2[:a] == x4[:a] == x6[:a]
        @test allequal([dropmeta(x[:a]) for x in [x1, x2, x3, x4, x5, x6]])

        @test x1[:b] == x3[:b]
        @test all(ismissing, x5[:b].data)
        @test x2[:b] == x4[:b]
        @test all(ismissing, x6[:b].data)
        @test allequal([dropmeta(x[:b]) for x in [x1, x2, x3, x4]])
        @test isequal(dropmeta(x5[:b]), dropmeta(x6[:b]))

        @test x1[:c] == x5[:c]
        @test all(isempty, x3[:c].bags.bags)
        @test x2[:c] == x6[:c]
        @test all(isempty, x4[:c].bags.bags)
        @test allequal([dropmeta(x[:c]) for x in [x1, x2, x5, x6]])
        @test dropmeta(x3[:c]) == dropmeta(x4[:c])

        @test isequal(ext(missing), ProductNode(; (k => e.children[k](missing) for k in [:a, :b, :c])...))
        @test isequal(ext(missing), ProductNode(; (k => e.children[k](missing) for k in [:a, :b, :c])...))
    end
end

@testset "PolymorphExtractor" begin
    @testset "without extract_missing" begin
        e = PolymorphExtractor((
            CategoricalExtractor(["foo", "bar", "baz"]),
            NGramExtractor()
        ))
        common_extractor_tests(e, "foo")
        common_extractor_tests(e, "")

        x = e(nothing)
        @test numobs(x) == numobs(x.data[1]) == numobs(x.data[2]) == 0
        @test x.data[1].data isa OneHotMatrix
        @test x.data[2].data isa NGramMatrix{String,Array{String,1},Int64}

        for ext in both_extractions(e)
            x = ext("foo")
            @test length(x.data) == 2
            @test size(x.data[1].data) == (4, 1)
            @test x.data[1].data isa OneHotMatrix
            @test findfirst(vec(x.data[1].data)) == e.extractors[1].category_map["foo"]
            @test size(x.data[2].data) == (2053, 1)
            @test x.data[2].data isa NGramMatrix{String, Vector{String}, Int64}
            @test x.data[2].data.S == ["foo"]
        end

        e = PolymorphExtractor(
            a = CategoricalExtractor(["foo", "bar"]),
            b = ArrayExtractor(NGramExtractor())
        )

        for ext in both_extractions(e)
            @test_throws IncompatibleExtractor ext(["foo", "bar"])
        end
    end

    @testset "with extract_missing" begin
        e = PolymorphExtractor((
            CategoricalExtractor(["foo", "bar", "baz"]),
            NGramExtractor()
        )) |> stabilizeextractor
        common_extractor_tests(e, "foo")
        common_extractor_tests(e, "")

        x = e(nothing)
        @test numobs(x) == numobs(x.data[1]) == numobs(x.data[2]) == 0
        @test x.data[1].data isa MaybeHotMatrix
        @test x.data[2].data isa NGramMatrix{Maybe{String}}

        for ext in both_extractions(e)
            x = ext("foo")
            @test length(x.data) == 2
            @test size(x.data[1].data) == (4, 1)
            @test x.data[1].data isa MaybeHotMatrix
            @test findfirst(vec(x.data[1].data)) == e.extractors[1].e.category_map["foo"]
            @test size(x.data[2].data) == (2053, 1)
            @test x.data[2].data isa NGramMatrix{Maybe{String}}
            @test x.data[2].data.S == ["foo"]
        end

        e = PolymorphExtractor(
            a = StableExtractor(CategoricalExtractor(["foo", "bar"])),
            b = ArrayExtractor(StableExtractor(NGramExtractor()))
        )

        for ext in both_extractions(e)
            @test_throws IncompatibleExtractor ext(["foo", "bar"])
        end
    end
end
