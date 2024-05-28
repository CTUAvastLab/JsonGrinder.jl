@testset "ArrayExtractor" begin
    for (inner_e, js) in zip(
        [ CategoricalExtractor(2:4), ScalarExtractor(), NGramExtractor() ],
        [ [2, 3, 4], [2, 3, 4], ["foo", "bar", "baz"] ])
        e = ArrayExtractor(inner_e)
        common_extractor_tests(e, js)
        common_extractor_tests(e, empty(js))

        x1 = e(js)
        x2 = e(js, store_input=Val(true))
        x3 = e(empty(js))
        x4 = e(empty(js))
        x5 = e(nothing)
        x6 = e(missing)
        x7 = e(missing, store_input=Val(true))

        @test x1.bags == x2.bags == AlignedBags([1:3])
        @test x3.bags == x4.bags == x6.bags == x7.bags == AlignedBags([0:-1])
        @test x5.bags == AlignedBags(Int[])

        @test dropmeta(x1) == dropmeta(x2)
        @test dropmeta(x3) == dropmeta(x4)
        @test isequal(dropmeta(x6), dropmeta(x7))

        @test x1.data == mapreduce(e.items, catobs, js)
        @test x2.data == mapreduce(x -> e.items(x; store_input=Val(true)), catobs, js)
        for x in [x3, x4, x5, x6, x7]
            @test isempty(x.data.data)
            @test numobs(x.data) == 0
            @test numobs(x.data.data) == 0
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
    @test_throws ErrorException e(jss[3])
    e = stabilizeextractor(e)
    common_extractor_tests(e, jss[2]; test_stability=false)

    x1 = e(jss[1])
    x2 = e(jss[1], store_input=Val(true))
    x3 = e(jss[2])
    x4 = e(jss[2], store_input=Val(true))
    x5 = e(jss[3])
    x6 = e(jss[3], store_input=Val(true))
    x7 = e(nothing)
    x8 = e(missing)
    x9 = e(missing, store_input=Val(true))

    @test isequal(reduce(catobs, e.(jss)), reduce(catobs, [x1, x3, x5]))
    @test isequal(reduce(catobs, e.(jss; store_input=Val(true))), reduce(catobs, [x2, x4, x6]))

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
end

@testset "PolymorphExtractor" begin
    @testset "without extract_missing" begin
        e = PolymorphExtractor((
            CategoricalExtractor(["foo", "bar", "baz"]),
            NGramExtractor()
        ))
        common_extractor_tests(e, "foo")
        common_extractor_tests(e, "")

        x = e("foo")
        @test length(x.data) == 2
        @test size(x.data[1].data) == (4, 1)
        @test x.data[1].data isa OneHotMatrix{UInt32, Vector{UInt32}}
        @test findfirst(vec(x.data[1].data)) == e.extractors[1].category_map["foo"]
        @test size(x.data[2].data) == (2053, 1)
        @test x.data[2].data isa NGramMatrix{String, Vector{String}, Int64}
        @test x.data[2].data.S == ["foo"]

        x = e(nothing)
        @test numobs(x) == numobs(x.data[1]) == numobs(x.data[2]) == 0
        @test x.data[1].data isa OneHotMatrix{UInt32, Vector{UInt32}}
        @test x.data[2].data isa NGramMatrix{String,Array{String,1},Int64}

        e2 = PolymorphExtractor((
            CategoricalExtractor(["foo", "bar", "baz"]),
            NGramExtractor()
        ))
        @test hash(e) == hash(e2)
        @test e == e2

        e3 = PolymorphExtractor((
            CategoricalExtractor(["foo", "bar"]),
            NGramExtractor()
        ))
        @test hash(e) ≠ hash(e3)
        @test e ≠ e3

        e = PolymorphExtractor(
            a = CategoricalExtractor(["foo", "bar"]),
            b = ArrayExtractor(NGramExtractor())
        )

        @test_throws MethodError e(["foo", "bar"])
        @test_throws MethodError e.extractors[:a](["foo"])
        @test e.extractors[:b](["foo"]) isa BagNode
    end

    @testset "with extract_missing" begin
        e = PolymorphExtractor((
            CategoricalExtractor(["foo", "bar", "baz"]),
            NGramExtractor()
        )) |> stabilizeextractor
        common_extractor_tests(e, "foo")
        common_extractor_tests(e, "")

        x = e("foo")
        @test length(x.data) == 2
        @test size(x.data[1].data) == (4, 1)
        @test x.data[1].data isa MaybeHotMatrix{Maybe{UInt32}, Maybe{Bool}}
        @test findfirst(vec(x.data[1].data)) == e.extractors[1].e.category_map["foo"]
        @test size(x.data[2].data) == (2053, 1)
        @test x.data[2].data isa NGramMatrix{Maybe{String}, Vector{Maybe{String}}, Maybe{Int64}}
        @test x.data[2].data.S == ["foo"]

        x = e(nothing)
        @test numobs(x) == numobs(x.data[1]) == numobs(x.data[2]) == 0
        @test x.data[1].data isa MaybeHotMatrix{Maybe{UInt32}, Maybe{Bool}}
        @test x.data[2].data isa NGramMatrix{Maybe{String}, Vector{Maybe{String}}, Maybe{Int64}}

        e2 = PolymorphExtractor((
            StableExtractor(CategoricalExtractor(["foo", "bar", "baz"])),
            StableExtractor(NGramExtractor())
        ))
        @test hash(e) === hash(e2)
        @test e == e2

        e3 = PolymorphExtractor((
            StableExtractor(CategoricalExtractor(["foo", "bar"])),
            NGramExtractor()
        ))
        @test hash(e) !== hash(e3)
        @test e != e3

        e = PolymorphExtractor(
            a = StableExtractor(CategoricalExtractor(["foo", "bar"])),
            b = ArrayExtractor(StableExtractor(NGramExtractor()))
        )

        @test_throws MethodError e(["foo", "bar"])
        @test_throws MethodError e.extractors[:a](["foo"])
        @test e.extractors[:b](["foo"]) isa BagNode
    end
end
