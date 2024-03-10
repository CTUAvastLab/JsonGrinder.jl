using JsonGrinder, JSON, Test, SparseArrays, Flux, Random, HierarchicalUtils
using JsonGrinder: ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector
using JsonGrinder: extractempty
using Mill
using OneHotArrays
using LinearAlgebra
using Accessors

function less_categorical_scalar_extractor()
    [
    (e -> (keys_len = length(keys(e)); keys_len / e.updated < 0.5 && length(keys(e)) <= 10 && JsonGrinder.is_numeric_or_numeric_string(e)),
        (e, uniontypes) -> ExtractCategorical(keys(e), uniontypes)),
    (e -> JsonGrinder.is_intable(e),
        (e, uniontypes) -> JsonGrinder.extractscalar(Int32, e, uniontypes)),
    (e -> JsonGrinder.is_floatable(e),
         (e, uniontypes) -> JsonGrinder.extractscalar(JsonGrinder.FloatType, e, uniontypes)),
    # it's important that condition here would be lower than maxkeys
    (e -> (keys_len = length(keys(e)); keys_len / e.updated < 0.1 && keys_len < 10000 && !JsonGrinder.is_numeric_or_numeric_string(e)),
        (e, uniontypes) -> ExtractCategorical(keys(e), uniontypes)),
    (e -> true,
        (e, uniontypes) -> JsonGrinder.extractscalar(JsonGrinder.unify_types(e), e, uniontypes)),]
end

testing_settings = (; scalar_extractors = less_categorical_scalar_extractor())

function with_emptyismissing(f::Function, a)
    orig_val = Mill.emptyismissing()
    Mill.emptyismissing!(a)
    f()
    Mill.emptyismissing!(orig_val)
end

@testset "ExtractScalar" begin
    @testset "with uniontypes" begin
        sc = ExtractScalar(Float64,2,3,true)
        @test sc.uniontypes == true
        @test all(sc("5").data .== [9])
        @test all(sc(5).data .== [9])
        @test all(sc(nothing).data .=== [missing])
        @test all(sc(missing).data .=== [missing])
        @test numobs(sc(missing)) == 1
        @test numobs(sc(nothing)) == 1
        @test sc(extractempty).data isa Matrix{Union{Missing, Float64}}
        @test numobs(sc(extractempty)) == 0
        @test numobs(sc(5)) == 1

        sc = ExtractScalar(Float32, 0.5, 4.0, true)
        @test sc.uniontypes == true
        @test sc(1).data isa Matrix{Union{Missing, Float32}}
        @test sc(extractempty).data isa Matrix{Union{Missing, Float32}}

        sc = JsonGrinder.extractscalar(Float32, true)
        @test sc.uniontypes == true
        @test sc(1).data isa Matrix{Union{Missing, Float32}}
        @test sc(Dict(1=>1)).data isa Matrix{Union{Missing, Float32}}
        @test length(sc) == 1

        @testset "store_input" begin
            @test sc("5", store_input=true).data == sc("5", store_input=false).data
            @test sc("5", store_input=true).metadata == fill("5",1,1)
            @test isnothing(sc("5", store_input=false).metadata)
            @test sc(5, store_input=true).data == sc(5, store_input=false).data
            @test sc(5, store_input=true).metadata == fill(5,1,1)
            @test isnothing(sc(5, store_input=false).metadata)
            @test sc(nothing, store_input=true).data ≃ sc(nothing, store_input=false).data
            @test sc(nothing, store_input=true).metadata == fill(nothing,1,1)
            @test isnothing(sc(nothing, store_input=false).metadata)
        end
    end

    @testset "without uniontypes" begin
        sc1 = ExtractScalar(Float64,2,3,false)
        @test sc1.uniontypes == false
        @test all(sc1("5").data .== [9])
        @test all(sc1(5).data .== [9])
        @test_throws ErrorException sc1(nothing)
        @test_throws ErrorException sc1(missing)
        @test numobs(sc1(5)) == 1

        sc2 = ExtractScalar(Float32, 0.5, 4.0, false)
        @test sc2.uniontypes == false
        @test sc2(1).data isa Matrix{Float32}
        sc3 = JsonGrinder.extractscalar(Float32,false)
        @test sc3.uniontypes == false
        @test sc3(1).data isa Matrix{Float32}
        @test_throws ErrorException sc3(Dict(1=>1))
        @test length(sc3) == 1

        @testset "extractempty" begin
            @test sc1(extractempty).data isa Matrix{Float64}
            @test numobs(sc1(extractempty)) == 0
            @test sc2(extractempty).data isa Matrix{Float32}
            @test isnothing(sc2(extractempty, store_input=false).metadata)
            @test sc2(extractempty, store_input=true).metadata isa Matrix{UndefInitializer}
            @test size(sc2(extractempty, store_input=true).metadata) == (1,0)
        end

        @testset "store_input" begin
            @test sc3("5", store_input=true).data == sc3("5", store_input=false).data
               @test sc3("5", store_input=true).metadata == fill("5",1,1)
               @test isnothing(sc3("5", store_input=false).metadata)
               @test sc3(5, store_input=true).data == sc3(5, store_input=false).data
               @test sc3(5, store_input=true).metadata == fill(5,1,1)
               @test isnothing(sc3(5, store_input=false).metadata)
               @test_throws ErrorException sc3(nothing, store_input=true)
               @test_throws ErrorException sc3(nothing, store_input=true)
        end
    end
end
# todo: add for each extractor tests with and without uniontypes, and with and without store_input
# todo: categorize tests w.r.t. individual extractors, make a checklist of what each extractor needs to test
@testset "ExtractArray" begin
    sc = ExtractArray(ExtractCategorical(2:4))
    with_emptyismissing(false) do
        e234 = sc([2,3,4], store_input=false)
        en = sc(nothing, store_input=false)
        e234s = sc([2,3,4], store_input=true)
        ens = sc(nothing, store_input=true)
        @test all(e234.data.data .== Matrix(1.0I, 4, 3))
        @test numobs(en.data) == 0
        @test en.data.data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
        @test numobs(en.data.data) == 0
        @test all(en.bags.bags .== [0:-1])

        @testset "store_input" begin
            @test e234s.data.data == e234.data.data
            @test e234s.data.metadata == [2,3,4]
            @test e234s.data[1].metadata == [2]
            @test e234s.data[2].metadata == [3]
            @test e234s.data[3].metadata == [4]
            @test ens.data.data == en.data.data
            @test ens.metadata == [nothing]
            @test isnothing(en.metadata)
            @test isnothing(ens.data.metadata)
            @test isnothing(e234.data.metadata)
            @test isnothing(en.data.metadata)
        end
    end
    with_emptyismissing(true) do
        en = sc(nothing, store_input=false)
        ens = sc(nothing, store_input=true)
        em = sc(missing, store_input=false)
        ems = sc(missing, store_input=true)
        @test en.data isa Missing
        @test en.data ≃ em.data
        @test ens.data isa Missing
        @test ens.data ≃ ems.data
        @test isnothing(en.metadata)
        @test isnothing(em.metadata)
        @test ens.metadata == [nothing]
        @test ems.metadata ≃ [missing]
        @test all(en.bags.bags .== [0:-1])
        @test all(em.bags.bags .== [0:-1])
    end

    @testset "extractempty" begin
        @test numobs(sc(extractempty).data.data) == 0
        @test numobs(sc(extractempty).data) == 0
        @test isempty(sc(extractempty).bags.bags)
        @test sc(extractempty).data.data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
        with_emptyismissing(true) do
            @test numobs(sc(extractempty)) == 0
        end
        with_emptyismissing(false) do
            @test numobs(sc(extractempty)) == 0
        end
    end
    sc = ExtractArray(ExtractScalar(Float32))
    e234 = sc([2,3,4], store_input=false)
    en = sc(nothing, store_input=false)
    e234s = sc([2,3,4], store_input=true)
    ens = sc(nothing, store_input=true)
    @test all(e234.data.data .== [2 3 4])
    @test numobs(en.data) == 0
    @test all(en.bags.bags .== [0:-1])
    @test numobs(sc(Dict(1=>1)).data) == 0

    @test numobs(sc(extractempty).data.data) == 0
    @test numobs(sc(extractempty).data) == 0
    @test isempty(sc(extractempty).bags.bags)
    @test sc(extractempty).data.data isa Matrix{Union{Missing, Float32}}

    @test en.data.data isa Matrix{Union{Missing, Float32}}
    @test e234s.data.data == e234.data.data
    @test e234s.data.metadata == [2 3 4]
    @test e234s.data[1].metadata == fill(2,1,1)
    @test e234s.data[2].metadata == fill(3,1,1)
    @test e234s.data[3].metadata == fill(4,1,1)
    @test ens.data.data == en.data.data
    @test isnothing(en.data.metadata)
    @test ens.metadata == [nothing]
    @test isnothing(e234.data.metadata)
    @test isnothing(en.data.metadata)

    # testing https://github.com/CTUAvastLab/JsonGrinder.jl/issues/76
    e = ExtractArray(ExtractScalar(Float32))
    @test e([1,2,3]) == BagNode(
        ArrayNode([1. 2. 3.]),
        [1:3]
    )
    @test_throws MethodError e((1,2,3))
    @test e(nothing) == BagNode(
        ArrayNode(Matrix(fill(zero(Float32),1,0))),
        [0:-1]
    )
    @test_throws MethodError e(e)
end

@testset "ExtractVector" begin
    @testset "with uniontypes" begin
        sc1 = ExtractVector(5, true)
        e1 = sc1([1, 2, 2, 3, 4], store_input=false)
        e1s = sc1([1, 2, 2, 3, 4], store_input=true)
        e2s = sc1([1, 2, 2, 3], store_input=true)
        n1 = sc1(missing, store_input=false)
        n1s = sc1(missing, store_input=true)
        @test sc1.uniontypes == true
        @test e1.data == e1s.data
        @test e1.data isa Matrix{Union{Missing, Float32}}

        sc2 = ExtractVector{Int64}(5, true)
        e12234 = sc2([1, 2, 2, 3, 4], store_input=false)
        e12234s = sc2([1, 2, 2, 3, 4], store_input=true)
        en = sc2(nothing, store_input=false)
        ens = sc2(nothing, store_input=true)
        @test sc2.uniontypes == true
        @test e12234.data ≈ [1, 2, 2, 3, 4]
        @test e12234.data isa Matrix{Union{Missing, Int64}}
        @test e12234s.data ≈ e12234.data
        @test ens.data ≃ en.data
        @test en.data isa Matrix{Union{Missing, Int64}}
        @test en.data ≃ [missing missing missing missing missing]'

        sc3 = ExtractVector{Float32}(5, true)
        @test sc3.uniontypes == true
        # feature vector longer than expected
        sc122345 = sc3([1, 2, 2, 3, 4, 5], store_input=false)
        sc122345s = sc3([1, 2, 2, 3, 4, 5], store_input=true)
        sc12345 = sc3([1, 2, 3, 4, 5])
        @test sc122345.data == [1f0 2f0 2f0 3f0 4f0]'
        @test sc12345.data isa Matrix{Union{Missing, Float32}}
        e56 = sc3([5, 6], store_input=false)
        e56s = sc3([5, 6], store_input=true)
        @test e56.data ≃ [5f0 6f0 missing missing missing]'
        @test e56s.data ≃ e56.data
        @test sc122345s.data ≈ sc122345.data
        @test all(sc3(Dict(1=>2)).data .=== missing)

        @testset "extractempty" begin
            @test sc1(extractempty).data isa Matrix{Union{Missing, Float32}}
            @test numobs(sc1(extractempty).data) == 0
            @test numobs(sc1(extractempty)) == 0
            @test sc2(extractempty).data isa Matrix{Union{Missing, Int64}}
            @test numobs(sc2(extractempty).data) == 0
            @test numobs(sc2(extractempty)) == 0
        end

        @testset "store_input" begin
            @test e1s.metadata == [[1, 2, 2, 3, 4]]
            @test isnothing(e1.metadata)
            @test catobs(e1s, e1s).data == [1 1; 2 2; 2 2; 3 3; 4 4]
            @test catobs(e1s, e1s).metadata == [[1, 2, 2, 3, 4], [1, 2, 2, 3, 4]]
            @test catobs(e1s, e1s)[1].data == [1 2 2 3 4]'
            @test catobs(e1s, e1s)[1].metadata == [[1, 2, 2, 3, 4]]
            @test n1s.metadata ≃ [missing]
            @test catobs(e1s, n1s).metadata ≃ [[1, 2, 2, 3, 4], missing]
            @test e2s.data ≃ [1 2 2 3 missing]'
            @test e2s.metadata == [[1, 2, 2, 3]]
            @test e12234s.metadata == [[1, 2, 2, 3, 4]]
            @test ens.metadata == [nothing]
            @test sc122345s.metadata == [[1, 2, 2, 3, 4, 5]]
            @test isnothing(e56.metadata)
            @test e56s.metadata == [[5, 6]]
        end
    end
    @testset "without uniontypes" begin
        sc1 = ExtractVector(5, false)
        @test sc1.uniontypes == false
        e1 = sc1([1, 2, 2, 3, 4], store_input=false)
        e1s = sc1([1, 2, 2, 3, 4], store_input=true)
        @test e1.data == [1f0 2f0 2f0 3f0 4f0]'
        @test e1.data isa Matrix{Float32}
        @test e1.data == e1s.data

        sc2 = ExtractVector{Int64}(5, false)
        @test sc2.uniontypes == false
        @test all(sc2([1, 2, 2, 3, 4]).data .== [1, 2, 2, 3, 4])
        @test sc2([1, 2, 2, 3, 4]).data isa Array{Int64, 2}

        sc3 = ExtractVector{Float32}(5, false)
        @test sc3.uniontypes == false

        # feature vector longer than expected
        @test sc3([1, 2, 2, 3, 4, 5]).data == [1f0 2f0 2f0 3f0 4f0]'
        @test sc3([1, 2, 3, 4, 5]).data isa Matrix{Float32}


        @testset "extractempty" begin
            @test sc1(extractempty).data isa Matrix{Float32}
            @test numobs(sc1(extractempty).data) == 0
            @test sc2(extractempty).data isa Matrix{Int64}
            @test numobs(sc2(extractempty).data) == 0
            @test sc3(extractempty).data isa Matrix{Float32}
            @test numobs(sc3(extractempty).data) == 0
        end

        @testset "store_input" begin
            @test e1s.metadata == [[1, 2, 2, 3, 4]]
            @test catobs(e1s, e1s).data == [1 1; 2 2; 2 2; 3 3; 4 4]
            @test catobs(e1s, e1s).metadata == [[1, 2, 2, 3, 4], [1, 2, 2, 3, 4]]
            @test catobs(e1s, e1s)[1].data == [1 2 2 3 4]'
            @test catobs(e1s, e1s)[1].metadata == [[1, 2, 2, 3, 4]]
            @test isnothing(e1.metadata)
        end

        @testset "missing" begin
            @test_throws ErrorException sc1(nothing, store_input=false)
            @test_throws ErrorException sc1(nothing, store_input=true)
            @test_throws ErrorException sc2(nothing, store_input=false)
            @test_throws ErrorException sc2(nothing, store_input=true)
            @test_throws ErrorException sc1(missing)
            @test_throws ErrorException sc2(missing)
            @test_throws ErrorException sc1([5, 6])
            @test_throws ErrorException sc3([5, 6])
            @test_throws ErrorException sc3(Dict(1=>2))
        end
    end
end

@testset "ExtractDict" begin
    dict = Dict("a" => ExtractScalar(Float64,2,3),
                "b" => ExtractScalar(Float64),
                "c" => ExtractArray(ExtractScalar(Float64,2,3)))
    br = ExtractDict(dict)
    a1 = br(Dict("a" => 5, "b" => 7, "c" => [1,2,3,4]))
    a2 = br(Dict("a" => 5, "b" => 7))
    a3 = br(Dict("a" => 5, "c" => [1,2,3,4]))

    @test catobs(a1,a1)[:a].data ≈ [9 9]
    @test catobs(a1,a1)[:b].data ≈ [7 7]
    @test catobs(a1,a1)[:c].data.data ≈  [-3 0 3 6 -3 0 3 6]
    @test all(catobs(a1,a1)[:c].bags .== [1:4,5:8])

    @test catobs(a1,a2)[:a].data ≈ [9 9]
    @test catobs(a1,a2)[:b].data ≈ [7 7]
    @test catobs(a1,a2)[:c].data.data ≈ [-3 0 3 6]
    @test all(catobs(a1,a2)[:c].bags .== [1:4,0:-1])

    @test catobs(a2,a3)[:a].data ≈ [9 9]
    @test catobs(a2,a3)[:b].data ≃ [7.0 missing]
    @test catobs(a2,a3)[:c].data.data ≈ [-3 0 3 6]
    @test all(catobs(a2,a3)[:c].bags .== [0:-1,1:4])

    @test catobs(a1,a3)[:a].data ≈ [9 9]
    @test catobs(a1,a3)[:b].data ≃ [7.0 missing]
    @test catobs(a1,a3)[:c].data.data ≈ [-3 0 3 6 -3 0 3 6]
    @test all(catobs(a1,a3)[:c].bags .== [1:4,5:8])

    @test a1[:a].data ≈ [9]
    @test a1[:b].data ≈ [7]
    @test a2[:a].data ≈ [9]
    @test a2[:b].data ≈ [7]
    @test a3[:a].data ≈ [9]
    @test a3[:b].data ≃ hcat(missing)
    @test a1[:c].data.data ≈ [-3 0 3 6]
    @test all(a1[:c].bags .== [1:4])

    @test a3[:c].data.data ≈ [-3 0 3 6]
    @test all(a3[:c].bags .== [1:4])
    @test catobs(a3,a3)[:c].data.data ≈ [-3 0 3 6 -3 0 3 6]
    @test all(catobs(a3,a3)[:c].bags .== [1:4,5:8])

    @testset "missing with store input" begin
        br([], store_input=true)["U"].metadata ≃ hcat(nothing)
        br([], store_input=true)["k"].metadata ≃ hcat(nothing)
    end
    @testset "extractempty" begin
        a4 = br(extractempty)
        @test numobs(a4) == 0
        @test numobs(a4[:a]) == 0
        @test a4[:a].data isa Matrix{Union{Missing, Float64}}
        @test numobs(a4[:b]) == 0
        @test a4[:b].data isa Matrix{Union{Missing, Float64}}
        @test numobs(a4[:c]) == 0
        @test numobs(a4[:c].data) == 0
        @test a4[:c].data.data isa Matrix{Union{Missing, Float64}}
    end
    @testset "Nested Missing Arrays" begin
        dict = Dict("a" => ExtractArray(ExtractScalar(Float32,2,3)),
            "b" => ExtractArray(ExtractScalar(Float32,2,3)))
        br = ExtractDict(dict)
        a1 = br(Dict("a" => [1,2,3], "b" => [1,2,3,4]), store_input=false)
        a2 = br(Dict("b" => [2,3,4]), store_input=false)
        a3 = br(Dict("a" => [2,3,4]), store_input=false)
        a4 = br(Dict{String, Any}(), store_input=false)
        a1s = br(Dict("a" => [1,2,3], "b" => [1,2,3,4]), store_input=true)
        a2s = br(Dict("b" => [2,3,4]), store_input=true)
        a3s = br(Dict("a" => [2,3,4]), store_input=true)
        a4s = br(Dict{String, Any}(), store_input=true)

        @test all(catobs(a1,a2).data[1].data.data .== [-3.0  0.0  3.0  6.0  0.0  3.0  6.0])
        @test all(catobs(a1,a2).data[1].bags .== [1:4, 5:7])
        @test all(catobs(a1,a2).data[2].data.data .== [-3.0  0.0  3.0])
        @test all(catobs(a1,a2).data[2].bags .== [1:3, 0:-1])


        @test all(catobs(a2,a3).data[1].data.data .== [0.0  3.0  6.0])
        @test all(catobs(a2,a3).data[1].bags .== [1:3, 0:-1])
        @test all(catobs(a2,a3).data[2].data.data .== [0 3 6])
        @test all(catobs(a2,a3).data[2].bags .== [0:-1, 1:3])

        @test all(catobs(a1,a4).data[1].data.data .== [-3.0  0.0  3.0  6.0])
        @test all(catobs(a1,a4).data[1].bags .== [1:4, 0:-1])
        @test all(catobs(a1,a4).data[2].data.data .== [-3.0  0.0  3.0])
        @test all(catobs(a1,a4).data[2].bags .== [1:3, 0:-1])

        @test all(a4.data[2].data.data isa Matrix{Union{Missing, Float32}})
        # todo: ověřit catobsování empty bagů s plnými bagy s metadaty jestli to funguje u všech možných extraktorů uvnitř bagu
        @test catobs(a1,a4).data[1].data.data == catobs(a1s,a4s).data[1].data.data
        @test catobs(a1,a4).data[1].bags == catobs(a1s,a4s).data[1].bags
        @test catobs(a1,a4).data[2].data.data == catobs(a1s,a4s).data[2].data.data
        @test catobs(a1,a4).data[2].bags == catobs(a1,a4).data[2].bags

        @test catobs(a1s,a4s).data[1].data.metadata == [1 2 3 4]
        @test catobs(a1s,a4s).data[2].data.metadata == [1 2 3]
        @test a1s.data[1].data.metadata == [1 2 3 4]
        @test a1s.data[2].data.metadata == [1 2 3]
        @test a4s.data[1].data.metadata == zeros(1,0)
        @test a4s.data[2].data.metadata == zeros(1,0)

        a4 = br(extractempty)
        @test numobs(a4) == 0
        @test numobs(a4[:a]) == 0
        @test numobs(a4[:a].data) == 0
        @test a4[:a].data.data isa Matrix{Union{Missing, Float32}}
        @test numobs(a4[:b]) == 0
        @test numobs(a4[:b].data) == 0
        @test a4[:b].data.data isa Matrix{Union{Missing, Float32}}
    end
end

@testset "ExtractCategorical" begin
    e = ExtractCategorical(["a","b"], true)
    ea = e("a", store_input=false)
    eb = e("b", store_input=false)
    ez = e("z", store_input=false)
    en = e(nothing, store_input=false)
    em = e(missing, store_input=false)
    eas = e("a", store_input=true)
    ebs = e("b", store_input=true)
    ezs = e("z", store_input=true)
    ens = e(nothing, store_input=true)
    @test e.uniontypes == true
    @test ea.data ≈ [1, 0, 0]
    @test eb.data ≈ [0, 1, 0]
    @test ez.data ≈ [0, 0, 1]
    @test en.data ≃ [missing missing missing]'
    @test em.data ≃ [missing missing missing]'
    @test ea.data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test en.data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test em.data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test e(extractempty).data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test numobs(e(extractempty)) == 0

    @test e(["a", "b"]).data ≃ [missing missing missing]'
    @test mapreduce(e, catobs, ["a", "b"]).data ≈ [1 0; 0 1; 0 0]
    @test e(["a", missing]).data ≃ [missing missing missing]'
    @test mapreduce(e, catobs, ["a", missing]).data ≃ [true missing; false missing; false missing]
    @test e(["a", missing, "x"]).data ≃ [missing missing missing]'
    @test mapreduce(e, catobs, ["a", missing, "x"]).data ≃ [true missing false; false missing false; false missing true]
    @test e(["a", "b"]).data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test mapreduce(e, catobs, ["a", "b"]).data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test e(["a", "b", nothing]).data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}
    @test mapreduce(e, catobs, ["a", "b", nothing]).data isa MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}

    @test catobs(ea, eb).data ≈ [1 0; 0 1; 0 0]
    @test reduce(catobs, [ea.data, eb.data]) ≈ [1 0; 0 1; 0 0]
    @test hcat(ea.data, eb.data) ≈ [1 0; 0 1; 0 0]
    @test e(Dict(1=>2)).data |> collect ≃ [missing missing missing]'

    @test catobs(eas, ebs).data == catobs(ea, eb).data
    @test reduce(catobs, [eas.data, ebs.data]) == reduce(catobs, [ea.data, eb.data])
    @test e(Dict(1=>2)).data ≃ [missing missing missing]'

    @test catobs(eas, ebs).metadata == ["a", "b"]
    @test e(Dict(1=>2), store_input=true).metadata == [Dict(1=>2)]

    @test numobs(ea) == 1
    @test numobs(eb) == 1
    @test numobs(ez) == 1
    @test numobs(en) == 1
    @test numobs(em) == 1
    @test numobs(em.data) == 1
    @test numobs(e([missing, nothing])) == 1
    @test numobs(mapreduce(e, catobs, [missing, nothing])) == 2
    @test numobs(e([missing, nothing, "a"])) == 1
    @test numobs(mapreduce(e, catobs, [missing, nothing, "a"])) == 3

    @test isnothing(ExtractCategorical([], true))
    e2 = ExtractCategorical(JsonGrinder.Entry(Dict("a"=>1,"c"=>1), 2), true)
    @test e2.uniontypes == true
    @test e2("a").data ≈ [1, 0, 0]
    @test e2("c").data ≈ [0, 1, 0]
    @test e2("b").data ≈ [0, 0, 1]
    @test e2(nothing).data ≃ [missing missing missing]'
    @test e2(missing).data ≃ [missing missing missing]'

    e3 = ExtractCategorical(JsonGrinder.Entry(Dict(1=>1,2=>1), 2), true)
    @test e3.uniontypes == true
    @test e3(1).data ≈ [1, 0, 0]
    @test e3(2).data ≈ [0, 1, 0]
    @test e3(4).data ≈ [0, 0, 1]
    @test e3(1.).data ≈ [1, 0, 0]
    @test e3(2.).data ≈ [0, 1, 0]
    @test e3(4.).data ≈ [0, 0, 1]
    @test e3([]).data ≃ [missing missing missing]'

    e4 = ExtractCategorical(JsonGrinder.Entry(Dict(1.0=>1,2.0=>1), 2), true)
    @test e4.uniontypes == true
    @test e4(1).data ≈ [1, 0, 0]
    @test e4(2).data ≈ [0, 1, 0]
    @test e4(4).data ≈ [0, 0, 1]
    @test e4(1.).data ≈ [1, 0, 0]
    @test e4(2.).data ≈ [0, 1, 0]
    @test e4(4.).data ≈ [0, 0, 1]
    @test e4([]).data ≃ [missing missing missing]'

    e = ExtractCategorical(["a","b"], false)
    @test e.uniontypes == false
    @test e("a").data ≈ [1, 0, 0]
    @test e("b").data ≈ [0, 1, 0]
    @test e("z").data ≈ [0, 0, 1]
    @test_throws ErrorException e(nothing)
    @test_throws ErrorException e(missing)
    @test e("a").data isa OneHotMatrix{UInt32, Vector{UInt32}}
    @test e(extractempty).data isa OneHotMatrix{UInt32, Vector{UInt32}}
    @test numobs(e(extractempty)) == 0

    @test mapreduce(e, catobs, ["a", "b"]).data ≈ [1 0; 0 1; 0 0]
    @test_throws ErrorException e(["a", "b"]).data
    @test_throws ErrorException e(["a", missing])
    @test_throws ErrorException e(["a", missing, "x"])
    @test mapreduce(e, catobs, ["a", "b"]).data isa OneHotMatrix{UInt32, Vector{UInt32}}
    @test_throws ErrorException e(["a", "b", nothing])

    @test isnothing(ExtractCategorical([], false))
    e2 = ExtractCategorical(JsonGrinder.Entry(Dict("a"=>1,"c"=>1), 2), false)
    @test e2.uniontypes == false
    @test e2("a").data ≈ [1, 0, 0]
    @test e2("c").data ≈ [0, 1, 0]
    @test e2("b").data ≈ [0, 0, 1]
    @test_throws ErrorException e2(nothing)
    @test_throws ErrorException e2(missing)

    @test catobs(e("a"), e("b")).data ≈ [1 0; 0 1; 0 0]
    @test reduce(catobs, [e("a").data, e("b").data]) ≈ [1 0; 0 1; 0 0]
    @test hcat(e("a").data, e("b").data) ≈ [1 0; 0 1; 0 0]
    @test_throws ErrorException e(Dict(1=>2))

    @test numobs(e("a")) == 1
    @test numobs(e("b")) == 1
    @test numobs(e("z")) == 1
    @test_throws ErrorException numobs(e(nothing))
    @test_throws ErrorException numobs(e(missing))
    @test_throws ErrorException numobs(e([missing, nothing]))
    @test_throws ErrorException numobs(e([missing, nothing, "a"]))

    e3 = ExtractCategorical(JsonGrinder.Entry(Dict(1=>1,2=>1), 2), false)
    @test e3.uniontypes == false
    @test e3(1).data ≈ [1, 0, 0]
    @test e3(2).data ≈ [0, 1, 0]
    @test e3(4).data ≈ [0, 0, 1]
    @test e3(1.).data ≈ [1, 0, 0]
    @test e3(2.).data ≈ [0, 1, 0]
    @test e3(4.).data ≈ [0, 0, 1]
    @test_throws ErrorException isequal(e3([]).data, [missing missing missing]')

    e4 = ExtractCategorical(JsonGrinder.Entry(Dict(1.0=>1,2.0=>1), 2), false)
    @test e4.uniontypes == false
    @test e4(1).data ≈ [1, 0, 0]
    @test e4(2).data ≈ [0, 1, 0]
    @test e4(4).data ≈ [0, 0, 1]
    @test e4(1.).data ≈ [1, 0, 0]
    @test e4(2.).data ≈ [0, 1, 0]
    @test e4(4.).data ≈ [0, 0, 1]
    @test_throws ErrorException isequal(e4([]).data, [missing missing missing]')

    @testset "type conversions" begin
        j1 = JSON.parse("""{"a": "4"}""")
        j2 = JSON.parse("""{"a": "11.5"}""")
        j3 = JSON.parse("""{"a": 7}""")
        j4 = JSON.parse("""{"a": 4.5}""")

        sch = JsonGrinder.schema([j1,j2,j3,j4])

        ext = suggestextractor(sch)

        @test ext(Dict("a"=>4)) == ext(Dict("a"=>4.0))
        @test ext(Dict("a"=>4)) == ext(Dict("a"=>4f0))
        @test ext(Dict("a"=>4)) == ext(Dict("a"=>"4"))
        @test ext(Dict("a"=>4)) == ext(Dict("a"=>"4.0"))
        # todo: add here metadata test
    end

    @testset "long strings trimming" begin
        d1 = Dict("key" => String(rand('a':'b', 20000)))
        d2 = Dict("key" => String(rand('a':'b', 20000)))
        sch = JsonGrinder.schema(rand([ d1, d2 ], 10000))

        e = suggestextractor(sch)
        @test e(d1) != e(d2)
        @test e(d1)[:key].data ≈ [1,0,0]
        @test e(d2)[:key].data ≈ [0,1,0]

        e2 = suggestextractor(sch)
        @reset e2.dict[:key] = JsonGrinder.extractscalar(String, sch[:key])
        @test e2(d1) != e2(d2)
    end
end

@testset "ExtractString" begin
    e = ExtractString(true)
    ehello = e("Hello", store_input=false)
    ehellos = e("Hello", store_input=true)
    @test ehello.data.S == ["Hello"]
    @test ehello.data == ehellos.data
    @test e(Symbol("Hello")).data.S == ["Hello"]
    @test e(["Hello", "world"]).data.S ≃ [missing]
    @test mapreduce(e, catobs, ["Hello", "world"]).data.S == ["Hello", "world"]

    @test e(missing).data.S ≃ [missing]
    @test e(nothing).data.S ≃ [missing]
    @test isequal(e(Dict(1=>2)), e(missing))
    @test ehello isa ArrayNode{NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}},Nothing}
    @test ehello.data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
    @test e(missing).data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
    @test e(nothing).data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
    @test ehellos.metadata == ["Hello"]
    @test numobs(e(extractempty)) == 0

    e = ExtractString(false)
    @test e("Hello").data.S == ["Hello"]
    @test e(Symbol("Hello")).data.S == ["Hello"]
    @test_throws ErrorException e(["Hello", "world"]).data.S
    @test mapreduce(e, catobs, ["Hello", "world"]).data.S == ["Hello", "world"]
    @test_throws ErrorException e(missing)
    @test_throws ErrorException e(nothing)
    @test_throws ErrorException e(Dict(1=>2))
    @test e("Hello") isa ArrayNode{NGramMatrix{String,Vector{String},Int64},Nothing}
    @test e("Hello").data isa NGramMatrix{String,Vector{String},Int64}
end

@testset "ExtractKeyAsField" begin
    JsonGrinder.updatemaxkeys!(1000)
    js = [Dict(randstring(5) => rand()) for _ in 1:1000]
    sch = JsonGrinder.schema(js)
    ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))
    @test ext isa JsonGrinder.ExtractKeyAsField

    b = ext(js[1])
    k = only(keys(js[1]))
    @test b.data[:item].data[1] ≈ (js[1][k] - ext.item.c) * ext.item.s
    @test b.data[:key].data.S[1] == k

    with_emptyismissing(true) do
        b = ext(nothing)
        @test numobs(b) == 1
        @test ismissing(b.data)
        b = ext(Dict())
        @test numobs(b) == 1
        @test ismissing(b.data)
    end
    with_emptyismissing(false) do
        b = ext(nothing)
        @test numobs(b) == 1
        @test numobs(b.data) == 0
        @test b.data[:key].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
        b = ext(Dict())
        @test numobs(b) == 1
        @test numobs(b.data) == 0
        @test b.data[:key].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
    end

    b = ext(extractempty)
    @test numobs(b) == 0
    @test numobs(b.data) == 0
    @test numobs(b.data[:item]) == 0
    @test b.data[:item].data isa Matrix{Float32}
    @test numobs(b.data[:key]) == 0
    @test b.data[:key].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}

    js = [Dict(randstring(5) => Dict("a" => rand(), "b" => randstring(1))) for _ in 1:1000]
    sch = JsonGrinder.schema(js)
    ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

    b = ext(js[1])
    k = only(keys(js[1]))
    i = ext.item(js[1][k])
    @test b.data[:item][:a].data == i[:a].data
    @test b.data[:item][:b].data == i[:b].data
    @test b.data[:key].data.S[1] == k
    @test isnothing(b.data[:key].metadata)
    @test isnothing(b.data[:item][:a].metadata)
    @test isnothing(b.data[:item][:b].metadata)

    b = ext(nothing)
    @test numobs(b) == 1
    @test numobs(b.data) == 0
    b = ext(Dict())
    @test numobs(b) == 1
    @test numobs(b.data) == 0

    b = ext(js[1], store_input=true)
    k = only(keys(js[1]))
    @test isnothing(b.metadata)
    @test b.data[:key].metadata == [k]
    @test b.data[:item][:a].metadata == fill(js[1][k]["a"],1,1)
    @test b.data[:item][:b].metadata == [js[1][k]["b"]]

    b = ext(Dict(), store_input=true)
    @test isnothing(b.metadata)
    @test isnothing(b.data[:key].metadata)
    @test isnothing(b.data[:item].metadata)

    b = ext(nothing, store_input=true)
    @test isnothing(b.metadata)
    @test isnothing(b.data.data.key.metadata)
    @test isnothing(b.data.data.item.metadata)

    j1 = JSON.parse("""{"a": 1}""")
    j2 = JSON.parse("""{"b": 2.5}""")
    j3 = JSON.parse("""{"c": 3.1}""")
    j4 = JSON.parse("""{"d": 5}""")
    j5 = JSON.parse("""{"e": 4.5}""")
    j6 = JSON.parse("""{"f": 5}""")
    sch = JsonGrinder.schema([j1, j2, j3, j4, j5, j6])
    e = JsonGrinder.key_as_field(sch, NamedTuple(), path = "")
    @test e isa JsonGrinder.ExtractKeyAsField

    e2 = JsonGrinder.key_as_field(sch, NamedTuple(), path = "")
    @test hash(e) === hash(e2)
    @test e == e2
end

# TODO taken from schema

# @testset "Extractor from schema" begin
# 	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
# 	j2 = JSON.parse("""{"a": 4, "c": {"a": {"a":[2,3],"b":[5,6]}}}""")
# 	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
# 	j4 = JSON.parse("""{"a": 4, "b": {}}""")
# 	j5 = JSON.parse("""{"b": {}}""")
# 	j6 = JSON.parse("""{}""")
#
# 	sch = schema([j1,j2,j3,j4,j5,j6])
# 	ext = suggestextractor(sch, testing_settings)
#
# 	@test ext[:a] isa ExtractCategorical
# 	@test ext[:b][:a] isa ExtractVector{Float32}
# 	@test ext[:b][:b] isa ExtractScalar{Float32}
# 	@test ext[:c][:a][:a] isa ExtractArray{ExtractScalar{Float32}}
# 	@test ext[:c][:a][:b] isa ExtractArray{ExtractScalar{Float32}}
#
# 	e1 = ext(j1)
# 	@test e1[:a].data ≈ [1, 0]
# 	@test e1[:b][:a].data ≈ [1, 2, 3]
# 	@test e1[:b][:b].data ≈ [0]
# 	@test e1[:c][:a][:a].data.data ≈ [0. 0.5 1.]
# 	@test e1[:c][:a][:b].data.data ≈ [0. 0.5 1.]
# end
# @testset "Empty string vs missing key testing" begin
# 	j1 = JSON.parse("""{"a": "b", "b": ""}""")
# 	j2 = JSON.parse("""{"a": "a", "b": "c"}""")
# 	sch1 = JsonGrinder.schema([j1,j2])
#
# 	j1 = JSON.parse("""{"a": "b"}""")
# 	j2 = JSON.parse("""{"a": "a", "b": "c"}""")
# 	sch2 = JsonGrinder.schema([j1,j2])
#
# 	ext1 = suggestextractor(sch1)
# 	ext2 = suggestextractor(sch2)
#
# 	m1 = reflectinmodel(sch1, ext1)
# 	m2 = reflectinmodel(sch2, ext2)
#
# 	@test m1[:b].m isa Dense
# 	@test m1[:b].m.weight isa Matrix
# 	@test m2[:b].m isa PostImputingDense
# 	@test m2[:b].m.weight isa PostImputingMatrix
# 	@test buf_printtree(m1) != buf_printtree(m2)
# end

	# TODO: add tests for array and empty dict, and which extractors it generates
	# basically test sth. like this
	# j1 = JSON.parse("""{"a": 4, "b": [{"a":[1,2,3],"b": 1}],"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	# j2 = JSON.parse("""{"a": 4, "c": {"a": {"a":[2,3],"b":[5,6]}}}""")
	# j3 = JSON.parse("""{"a": 4, "b": [{"a":[1,2,3],"b": 1}]}""")
	# j4 = JSON.parse("""{"a": 4, "b": [{}]}""")
	# j5 = JSON.parse("""{"b": {}}""")
	# j6 = JSON.parse("""{}""")

@testset "equals and hash test" begin
    other1 = Dict(
        "a" => ExtractArray(ExtractScalar(Float64,2,3)),
        "b" => ExtractArray(ExtractScalar(Float64,2,3)),
        "c" => ExtractCategorical(["a","b"]),
        "d" => ExtractVector(4),
    )
    br1 = ExtractDict(other1)
    other11 = Dict(
        "a" => ExtractArray(br1),
        "b" => ExtractScalar(Float64,2,3),
    )
    br11 = ExtractDict(other11)

    other2 = Dict(
        "a" => ExtractArray(ExtractScalar(Float64,2,3)),
        "b" => ExtractArray(ExtractScalar(Float64,2,3)),
        "c" => ExtractCategorical(["a","b"]),
        "d" => ExtractVector(4),
    )
    br2 = ExtractDict(other2)
    other22 = Dict("a" => ExtractArray(br2), "b" => ExtractScalar(Float64,2,3))
    br22 = ExtractDict(other22)

    @test hash(br11) === hash(br22)
    @test hash(br11) !== hash(br1)
    @test hash(br11) !== hash(br2)
    @test hash(br1) === hash(br2)

    @test br11 == br22
    @test br11 != br1
    @test br11 != br2
    @test br1 == br2
end
# todo: add tests for settings of suggestextractor!!!
# todo: add tests for single keyed dict, that model generated from such jsons behaves as we want
@testset "Extractor skip empty lists" begin
    j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b": [], "c": [[], []], "d": 1, "e": {"a": 1}, "f": {"a": []}}""")
    j2 = JSON.parse("""{"a": [{"a":3},{"b":4}], "b": [], "c": [[]], "d": 1, "e": {"a": 2}, "f": {"a": []}}""")
    j3 = JSON.parse("""{"a": [{"a":1},{"b":3}], "b": [], "c": [[], [], [], []], "d": 2, "e": {"a": 3}, "f": {"a": []}}""")
    j4 = JSON.parse("""{"a": [{"a":2},{"b":4}], "b": [], "c": [], "d": 4, "e": {"a": 3}, "f": {"a": []}}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4])
    ext = suggestextractor(sch)
    @test ext[:a] isa ExtractArray
    @test isnothing(ext[:b])
    @test isnothing(ext[:c])
    @test ext[:d] isa ExtractCategorical
    @test ext[:e] isa ExtractDict
    @test isnothing(ext[:f])
end

@testset "Extractor of numbers as strings" begin
    j1 = JSON.parse("""{"a": "1", "b": "a", "c": "1.1", "d": 1.1, "e": "1.2", "f": 1, "g": "1"}""")
    j2 = JSON.parse("""{"a": "2", "b": "b", "c": "2",   "d": 2, "e": "1.3", "f": 2, "g": "2"}""")
    j3 = JSON.parse("""{"a": "3", "b": "c", "c": "2.3", "d": 2.3, "e": "1.4", "f": 3, "g": "3"}""")
    j4 = JSON.parse("""{"a": "4", "b": "c", "c": "5",   "d": 5, "e": "1.4", "f": 3, "g": "4"}""")
    j5_200 = [JSON.parse("""{"a": "5", "b": "$("c"^i)", "c": "5", "d": $(5+i/10), "e": "1.4", "f": 3, "g": "$i"}""") for i in 5:200]
    sch = JsonGrinder.schema([j1, j2, j3, j4, j5_200...])
    ext = suggestextractor(sch)

    @test ext[:a] isa ExtractCategorical
    @test ext[:b] isa ExtractString
    @test ext[:c] isa ExtractCategorical
    @test ext[:d] isa ExtractScalar{Float32}
    @test ext[:e] isa ExtractCategorical
    @test ext[:f] isa ExtractCategorical
    @test ext[:g] isa ExtractScalar{Float32}

    ext_j1 = ext(j1)
    ext_j2 = ext(j2)
    ext_j3 = ext(j3)
    ext_j4 = ext(j4)

    @test eltype(ext_j1[:a].data) <: Bool
    @test eltype(ext_j1[:b].data) <: Int64
    @test eltype(ext_j1[:c].data) <: Bool
    @test eltype(ext_j1[:d].data) <: Float32
    @test eltype(ext_j1[:e].data) <: Bool
    @test eltype(ext_j1[:f].data) <: Bool
    @test eltype(ext_j1[:g].data) <: Float32

    @test eltype(ext_j2[:a].data) <: Bool
    @test eltype(ext_j2[:b].data) <: Int64
    @test eltype(ext_j2[:c].data) <: Bool
    @test eltype(ext_j2[:d].data) <: Float32
    @test eltype(ext_j2[:e].data) <: Bool
    @test eltype(ext_j2[:f].data) <: Bool
    @test eltype(ext_j2[:g].data) <: Float32

    @test eltype(ext_j3[:a].data) <: Bool
    @test eltype(ext_j3[:b].data) <: Int64
    @test eltype(ext_j3[:c].data) <: Bool
    @test eltype(ext_j3[:d].data) <: Float32
    @test eltype(ext_j3[:e].data) <: Bool
    @test eltype(ext_j3[:f].data) <: Bool
    @test eltype(ext_j3[:g].data) <: Float32

    @test eltype(ext_j4[:a].data) <: Bool
    @test eltype(ext_j4[:b].data) <: Int64
    @test eltype(ext_j4[:c].data) <: Bool
    @test eltype(ext_j4[:d].data) <: Float32
    @test eltype(ext_j4[:e].data) <: Bool
    @test eltype(ext_j4[:f].data) <: Bool
    @test eltype(ext_j4[:g].data) <: Float32

    @test ext_j1["U"].data ≈ [0]
    @test ext_j2["U"].data ≈ [(2-1.1)/23.9]
    @test ext_j3["U"].data ≈ [(2.3-1.1)/23.9]
    @test ext_j4["U"].data ≈ [(5-1.1)/23.9]

    ext_j1s = ext(j1, store_input=true)
    ext_j2s = ext(j2, store_input=true)
    ext_j3s = ext(j3, store_input=true)
    ext_j4s = ext(j4, store_input=true)

    @test ext_j1["U"].data == ext_j1s["U"].data
    @test ext_j2["U"].data == ext_j2s["U"].data
    @test ext_j3["U"].data == ext_j3s["U"].data
    @test ext_j4["U"].data == ext_j4s["U"].data

    @test Mill.metadata.(values(ext_j1s.data)) == ([1], ["a"], ["1"], fill(1.1,1,1), ["1.2"], ["1.1"], fill("1",1,1))
    @test Mill.metadata.(values(ext_j2s.data)) == ([2], ["b"], ["2"], fill(2,1,1), ["1.3"], ["2"], fill("2",1,1))
    @test Mill.metadata.(values(ext_j3s.data)) == ([3], ["c"], ["3"], fill(2.3,1,1), ["1.4"], ["2.3"], fill("3",1,1))
    @test Mill.metadata.(values(ext_j4s.data)) == ([3], ["c"], ["4"], fill(5,1,1), ["1.4"], ["5"], fill("4",1,1))

    m = reflectinmodel(sch, ext)
    @test buf_printtree(m, limit=false) == """
    ProductModel ↦ Dense(52 => 10)  # 2 arrays, 530 params, 2.148 KiB
      ├── f: ArrayModel(Dense(4 => 10))  # 2 arrays, 50 params, 280 bytes
      ├── b: ArrayModel(Dense(2053 => 10))  # 2 arrays, 20_540 params, 80.312 KiB
      ├── a: ArrayModel(Dense(6 => 10))  # 2 arrays, 70 params, 360 bytes
      ├── d: ArrayModel(identity)
      ├── e: ArrayModel(Dense(4 => 10))  # 2 arrays, 50 params, 280 bytes
      ├── c: ArrayModel(Dense(5 => 10))  # 2 arrays, 60 params, 320 bytes
      ╰── g: ArrayModel(identity)
    """
end

# todo: add separate tests for reflectinmodel(sch, ext) to test behavior with various missing and non-missing stuff in schema
# e.g. empty string, missing keys, irregular schema and MultiRepresentation

@testset "is_numeric is_floatable is_intable" begin
	j1 = JSON.parse("""{"a": "4"}""")
	j2 = JSON.parse("""{"a": "11.5"}""")
	j3 = JSON.parse("""{"a": 7}""")
	j4 = JSON.parse("""{"a": 4.5}""")

	sch1234 = schema([j1,j2,j3,j4])
	sch12 = schema([j1,j2])
	sch34 = schema([j3,j4])
	sch13 = schema([j1,j3])
	sch3 = schema([j3])
	sch = schema([j1])
	e = sch1234[:a]

	expected_multientry = JsonGrinder.InconsistentEntry([
		JsonGrinder.Entry(Dict("4"=>1,"11.5"=>1),2),
		JsonGrinder.Entry(Dict(7=>1,4.5=>1),2)
	], 4)
	@test e == expected_multientry

	e_hash = hash(e)
	@test JsonGrinder.merge_entries_with_cast(e, Int32, Real) == expected_multientry
	# checking that merge_entries_with_cast is not mutating the argument
	@test e_hash == hash(e)

	expected_merged = JsonGrinder.InconsistentEntry([
		JsonGrinder.Entry(Dict(7=>1,4.0=>1,11.5=>1,4.5=>1),4)
	], 4)
	@test JsonGrinder.merge_entries_with_cast(e, JsonGrinder.FloatType, Real) == expected_merged
	# checking that merge_entries_with_cast is not mutating the argument
	@test e_hash == hash(e)
	@test JsonGrinder.merge_entries_with_cast(e, Int32, Real) != expected_merged

	e1234 = JsonGrinder.merge_entries_with_cast(e, JsonGrinder.FloatType, Real)[1]

	@test sch12[:a] == JsonGrinder.Entry(Dict("4" => 1, "11.5"=> 1),2)

	@test !JsonGrinder.is_intable(e1234)
	@test !JsonGrinder.is_floatable(e1234)
	@test JsonGrinder.is_numeric_entry(e1234, Real)

	@test !JsonGrinder.is_intable(sch12[:a])
	@test JsonGrinder.is_floatable(sch12[:a])
	@test !JsonGrinder.is_numeric_entry(sch12[:a], Real)
	# todo: fix it and make some predicates with true for both e1 and sch12[:a]
	@test !JsonGrinder.is_intable(sch34[:a])
	@test !JsonGrinder.is_floatable(sch34[:a])
	@test JsonGrinder.is_numeric_entry(sch34[:a], Real)

	expected_merged = JsonGrinder.InconsistentEntry([
		JsonGrinder.Entry(Dict(7=>1,4=>1),2)
	], 2)
	@test JsonGrinder.merge_entries_with_cast(sch13[:a], Int32, Real) == expected_merged

	e13 = JsonGrinder.merge_entries_with_cast(sch13[:a], Int32, Real)[1]

	@test !JsonGrinder.is_intable(e13)
	@test !JsonGrinder.is_floatable(e13)
	@test JsonGrinder.is_numeric_entry(e13, Real)

	@test !JsonGrinder.is_intable(sch3[:a])
	@test !JsonGrinder.is_floatable(sch3[:a])
	@test JsonGrinder.is_numeric_entry(sch3[:a], Real)

	@test JsonGrinder.is_intable(sch[:a])
	@test JsonGrinder.is_floatable(sch[:a])
	@test !JsonGrinder.is_numeric_entry(sch[:a], Real)
end

num_params(m) = m |> Flux.params .|> size .|> prod |> sum
params_empty(m) = m |> Flux.params .|> size |> isempty

@testset "suggestextractor with ints and floats numeric and stringy" begin
	j1 = JSON.parse("""{"a": "4"}""")
	j2 = JSON.parse("""{"a": "11.5"}""")
	j3 = JSON.parse("""{"a": 7}""")
	j4 = JSON.parse("""{"a": 4.5}""")

	sch1234 = schema([j1,j2,j3,j4])
	sch123 = schema([j1,j2,j3])
	sch12 = schema([j1,j2])
	sch23 = schema([j2,j3])
	sch14 = schema([j1,j4])
	sch34 = schema([j3,j4])

	ext1234 = suggestextractor(sch1234)
	ext123 = suggestextractor(sch123)
	ext12 = suggestextractor(sch12)
	ext23 = suggestextractor(sch23)
	ext34 = suggestextractor(sch34)
	ext14 = suggestextractor(sch14)

	# as expected, sometimes there is multirepresentation
	@test buf_printtree(ext12, trav=true) ==
	"""
	Dict [""]
	  ╰── a: Categorical d = 3 ["U"]
	"""

	@test buf_printtree(ext23, trav=true) ==
  	"""
	Dict [""]
	  ╰── a: MultiRepresentation ["U"]
	           ╰── e1: Categorical d = 3 ["k"]
	"""

  	@test buf_printtree(ext34, trav=true) ==
	"""
	Dict [""]
	  ╰── a: Categorical d = 3 ["U"]
	"""

  	@test buf_printtree(ext14, trav=true) ==
	"""
	Dict [""]
	  ╰── a: MultiRepresentation ["U"]
	           ╰── e1: Categorical d = 3 ["k"]
	"""

	# but that's not problem, there are identity layers, so number of parameters is same

	m12 = reflectinmodel(sch12, ext12)
	m23 = reflectinmodel(sch23, ext23)
	m34 = reflectinmodel(sch34, ext34)
	m14 = reflectinmodel(sch14, ext14)

	# testing that I have same numer of params
	@test num_params(m12) == 40
	@test num_params(m12) == num_params(m23)
	@test num_params(m12) == num_params(m34)
	@test num_params(m12) == num_params(m14)

	# now now with scalars
	ext1234 = suggestextractor(sch1234, testing_settings)
	ext123 = suggestextractor(sch123, testing_settings)
	ext12 = suggestextractor(sch12, testing_settings)
	ext23 = suggestextractor(sch23, testing_settings)
	ext34 = suggestextractor(sch34, testing_settings)
	ext14 = suggestextractor(sch14, testing_settings)

	# as expected, sometimes there is multirepresentation
	@test buf_printtree(ext12, trav=true) ==
	"""
	Dict [""]
	  ╰── a: Float32 ["U"]
	"""

	@test buf_printtree(ext23, trav=true) ==
  	"""
	Dict [""]
	  ╰── a: MultiRepresentation ["U"]
	           ╰── e1: Float32 ["k"]
	"""

  	@test buf_printtree(ext34, trav=true) ==
	"""
	Dict [""]
	  ╰── a: Float32 ["U"]
	"""

  	@test buf_printtree(ext14, trav=true) ==
	"""
	Dict [""]
	  ╰── a: MultiRepresentation ["U"]
	           ╰── e1: Float32 ["k"]
	"""

	# but that's not problem, there are identity layers, so number of parameters is same

	# by default there is only 1 scalar and indentities, so they have not params
	m12 = reflectinmodel(sch12, ext12)
	m23 = reflectinmodel(sch23, ext23)
	m34 = reflectinmodel(sch34, ext34)
	m14 = reflectinmodel(sch14, ext14)

	# testing that I have no params in all models
	@test params_empty(m12)
	@test params_empty(m23)
	@test params_empty(m34)
	@test params_empty(m14)
end

@testset "Suggest feature vector extraction" begin
    j1 = JSON.parse("""{"a": "1", "b": [1, 2, 3], "c": [1, 2, 3]}""")
    j2 = JSON.parse("""{"a": "2", "b": [2, 2, 3], "c": [1, 2, 3, 4]}""")
    j3 = JSON.parse("""{"a": "3", "b": [3, 2, 3], "c": [1, 2, 3, 4, 5]}""")
    j4 = JSON.parse("""{"a": "4", "b": [2, 3, 4], "c": [1, 2, 3]}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4])
    ext = suggestextractor(sch, testing_settings)

    @test ext[:a] isa ExtractScalar{Float32}
    @test ext[:b] isa ExtractVector
    @test ext[:b].n == 3
    @test ext[:c] isa ExtractArray{ExtractCategorical{Number,UInt32}}

    @test buf_printtree(ext, trav=true) ==
    """
    Dict [""]
      ├── a: Float32 ["E"]
      ├── b: FeatureVector with 3 items ["U"]
      ╰── c: Array of ["k"]
               ╰── Categorical d = 6 ["s"]
    """

    ext_j1 = ext(j1, store_input=false)
    ext_j2 = ext(j2, store_input=false)
    ext_j3 = ext(j3, store_input=false)
    ext_j4 = ext(j4, store_input=false)

    ext_j1s = ext(j1, store_input=true)
    ext_j2s = ext(j2, store_input=true)
    ext_j3s = ext(j3, store_input=true)
    ext_j4s = ext(j4, store_input=true)

    @test ext_j1["E"].data ≈ [0]
    @test ext_j2["E"].data ≈ [1/3]
    @test ext_j3["E"].data ≈ [2/3]
    @test ext_j4["E"].data ≈ [1]

    @test ext_j1["U"].data ≈ [1, 2, 3]
    @test ext_j2["U"].data ≈ [2, 2, 3]
    @test ext_j3["U"].data ≈ [3, 2, 3]
    @test ext_j4["U"].data ≈ [2, 3, 4]

    @test ext_j1["s"].data ≈ [
    1  0  0
     0  1  0
     0  0  1
     0  0  0
     0  0  0
     0  0  0]
    @test ext_j2["s"].data ≈ [
    1  0  0  0
     0  1  0  0
     0  0  1  0
     0  0  0  1
     0  0  0  0
     0  0  0  0
    ]
    @test ext_j3["s"].data ≈ [
    1  0  0  0  0
    0  1  0  0  0
    0  0  1  0  0
    0  0  0  1  0
    0  0  0  0  1
    0  0  0  0  0
    ]
    @test ext_j4["s"].data ≈ [
    1  0  0
     0  1  0
     0  0  1
     0  0  0
     0  0  0
     0  0  0
    ]

    for (a,b) in zip([ext_j1, ext_j2, ext_j3, ext_j4], [ext_j1s, ext_j2s, ext_j3s, ext_j4s])
        @test a["E"].data == b["E"].data
        @test a["U"].data == b["U"].data
        @test a["s"].data == b["s"].data
    end

    @test ext_j1s["U"].metadata == [[1, 2, 3]]
    @test ext_j2s["U"].metadata == [[2, 2, 3]]
    @test ext_j3s["U"].metadata == [[3, 2, 3]]
    @test ext_j4s["U"].metadata == [[2, 3, 4]]

    @test ext_j1s["s"].metadata == [1, 2, 3]
    @test ext_j2s["s"].metadata == [1, 2, 3, 4]
    @test ext_j3s["s"].metadata == [1, 2, 3, 4, 5]
    @test ext_j4s["s"].metadata == [1, 2, 3]
end

@testset "Suggest complex" begin
    JsonGrinder.updatemaxkeys!(1000)
    js = [Dict("a" => rand(), "b" => Dict(randstring(5) => rand()), "c"=>[rand(), rand()], "d"=>[rand() for i in 1:rand(1:10)]) for _ in 1:1000]
    sch = JsonGrinder.schema(js)
    ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

    @test ext[:a] isa ExtractScalar{Float32}
    @test ext[:b] isa JsonGrinder.ExtractKeyAsField
    @test ext[:b].key isa ExtractString
    @test ext[:b].item isa ExtractScalar{Float32}
    @test ext[:c] isa ExtractVector
    @test ext[:c].n == 2
    @test ext[:d] isa ExtractArray
end

@testset "Extractor typed missing bags" begin
    j1 = JSON.parse("""{"a": []}""")
    j2 = JSON.parse("""{"a": [1, 2]}""")
    j3 = JSON.parse("""{"a": [1, 2, 3]}""")
    j4 = JSON.parse("""{"a": [1, 2, 4, 5]}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4])
    ext = suggestextractor(sch, testing_settings)

    ext_j1 = ext(j1)
    ext_j2 = ext(j2)
    ext_j3 = ext(j3)
    ext_j4 = ext(j4)

    @test ext_j1[:a].data.data isa Matrix{Float32}
    @test ext_j2[:a].data.data isa Matrix{Float32}
    @test ext_j3[:a].data.data isa Matrix{Float32}
    @test ext_j4[:a].data.data isa Matrix{Float32}
end

@testset "testing irregular extractor" begin
    j1 = JSON.parse("""{"a": 4}""")
    j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}}""")
    j3 = JSON.parse("""{"a": [1, 2, 3, 4]}""")
    j4 = JSON.parse("""{"a": 5}""")
    j5 = JSON.parse("""{"a": 3}""")

    sch = schema([j1,j2,j3,j4,j5])
    ext = suggestextractor(sch, testing_settings)
    a = ext(j1)
    @test a[:a][:e1].data[1] == 0.5
    @test ismissing(a[:a][:e2].data[:a].data.S[1])
    @test numobs(a[:a][:e3]) == 1
    @test numobs(a[:a][:e3].data) == 1
end

@testset "Mixed scalar extraction" begin
    # todo: add test for extraction of numeric scalars from string and also missings, if it's all matrix and catobsing properly
    j1 = JSON.parse("""{"a": "1"}""")
    j2 = JSON.parse("""{"a": 4}""")
    j3 = JSON.parse("""{"a": "3.1"}""")
    j4 = JSON.parse("""{"a": 2.5}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4])
    sch_hash = hash(sch)
    ext = suggestextractor(sch, testing_settings)
    @test sch_hash == hash(sch)    # testing that my entry parkour does not modify schema
    @test nchildren(ext[:a]) == 1

    e1 = ext(j1)
    e2 = ext(j2)
    e3 = ext(j3)
    e4 = ext(j4)
    @test e1["k"].data ≈ [0]
    @test e2["k"].data ≈ [1]
    @test e3["k"].data ≈ [0.7]
    @test e4["k"].data ≈ [0.5]
end

@testset "merging numeric scalars" begin
    j1 = JSON.parse("""{"a": "1", "b":1}""")
    j2 = JSON.parse("""{"a": 4, "b":2}""")
    j3 = JSON.parse("""{"a": "3.1", "b":3}""")
    j4 = JSON.parse("""{"b":4}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4])
    ext = suggestextractor(sch, testing_settings)
    @test nchildren(ext[:a]) == 1

    e1 = ext(j1)
    e2 = ext(j2)
    e3 = ext(j3)
    e4 = ext(j4)
    @test e1["M"].data ≈ [0]
    @test e2["M"].data ≈ [1]
    @test e3["M"].data ≈ [0.7]
    @test e4["M"].data ≃ fill(missing,1,1)
    @test e1["U"].data ≈ [0]
    @test e2["U"].data ≈ [1/3]
    @test e3["U"].data ≈ [2/3]
    @test e4["U"].data ≈ [1]
end

@testset "Mixed scalar extraction with other types" begin
    j1 = JSON.parse("""{"a": "1"}""")
    j2 = JSON.parse("""{"a": 2.5}""")
    j3 = JSON.parse("""{"a": "3.1"}""")
    j4 = JSON.parse("""{"a": 5}""")
    j5 = JSON.parse("""{"a": "4.5"}""")
    j6 = JSON.parse("""{"a": [1, 2, 3, 4, 5]}""")
    j7 = JSON.parse("""{"a": {"Sylvanas is the worst warchief ever": "yes"}}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4, j5, j6, j7])
    ext = suggestextractor(sch, testing_settings)

    @test buf_printtree(sch) ==
    """
    [Dict]  # updated = 7
      ╰── a: [MultiEntry]  # updated = 7
               ├── 1: [Scalar - String], 3 unique values  # updated = 3
               ├── 2: [Scalar - Float64,Int64], 2 unique values  # updated = 2
               ├── 3: [List]  # updated = 1
               │        ╰── [Scalar - Int64], 5 unique values  # updated = 5
               ╰── 4: [Dict]  # updated = 1
                        ╰── Sylvanas is the worst warchief ever: [Scalar - String], 1 unique values  # updated = 1
    """

    @test buf_printtree(ext, trav=true) ==
    """
    Dict [""]
      ╰── a: MultiRepresentation ["U"]
               ├── e1: FeatureVector with 5 items ["c"]
               ├── e2: Dict ["k"]
               │         ╰── Sylvanas is the worst warchief ever: String ["o"]
               ╰── e3: Float32 ["s"]
    """

    e1 = ext(j1)
    e2 = ext(j2)
    e3 = ext(j3)
    e4 = ext(j4)
    e5 = ext(j5)
    @test e1["s"].data ≈ [0]
    @test e2["s"].data ≈ [0.375]
    @test e3["s"].data ≈ [0.525]
    @test e4["s"].data ≈ [1.0]
    @test e5["s"].data ≈ [0.875]
    @test buf_printtree(e1) ==
    """
    ProductNode  # 1 obs, 48 bytes
      ╰── a: ProductNode  # 1 obs, 48 bytes
               ├── e1: ArrayNode(5×1 Array with Union{Missing, Float32} elements)  # 1 obs, 73 bytes
               ├── e2: ProductNode  # 1 obs, 32 bytes
               │         ╰── Sylvanas is the worst warchief ever: ArrayNode(2053×1 NGramMatrix with Union{Missing, Int64} elements)  # 1 obs, 112 bytes
               ╰── e3: ArrayNode(1×1 Array with Union{Missing, Float32} elements)  # 1 obs, 53 bytes
    """
    @test ext[:a][1] == ext["c"]
end

@testset "mixing numeric and non-numeric strings" begin
    j1 = JSON.parse("""{"a": "hello"}""")
    j2 = JSON.parse("""{"a": "4"}""")
    j3 = JSON.parse("""{"a": 5}""")
    j4 = JSON.parse("""{"a": 3.0}""")
    j5 = JSON.parse("""{"a": [1, 2, 3, 4, 5]}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4, j5])
    ext = suggestextractor(sch, testing_settings)

    @test buf_printtree(sch) ==
    """
    [Dict]  # updated = 5
      ╰── a: [MultiEntry]  # updated = 5
               ├── 1: [Scalar - String], 2 unique values  # updated = 2
               ├── 2: [Scalar - Float64,Int64], 2 unique values  # updated = 2
               ╰── 3: [List]  # updated = 1
                        ╰── [Scalar - Int64], 5 unique values  # updated = 5
    """

    @test buf_printtree(ext) ==
    """
    Dict
      ╰── a: MultiRepresentation
               ├── e1: String
               ├── e2: Float32
               ╰── e3: FeatureVector with 5 items
    """

    e1 = ext(j1)
    e2 = ext(j2)
    e3 = ext(j3)
    e4 = ext(j4)
    e5 = ext(j5)
    @test all(e1["k"].data .=== [missing])
    @test e2["k"].data ≈ [0.5]
    @test e3["k"].data ≈ [1.0]
    @test e4["k"].data ≈ [0.0]
    @test all(e5["k"].data .=== [missing])

    @test hash(ext) !== hash(suggestextractor(JsonGrinder.schema([j1, j2, j4, j5])))
end

@testset "empty string and substring" begin
    a, b, c = split("a b ", " ")
    d = "d"
    e = ""
    f = 5.2
    @test a isa SubString{String}
    @test b isa SubString{String}
    @test c isa SubString{String}
    @test d isa String
    @test e isa String
    @test f isa AbstractFloat
    @test c == ""
    ext = JsonGrinder.extractscalar(AbstractString)
    @test SparseMatrixCSC(ext(c).data) == SparseMatrixCSC(ext(e).data)
    @test all(ext(f).data.S .=== ext(nothing).data.S)

    @test ext(f, store_input=true) != ext(nothing, store_input=true)
    @test ext(f, store_input=true).data ≃ ext(nothing, store_input=true).data
    @test ext(a, store_input=true).metadata == ["a"]
    @test ext(b, store_input=true).metadata == ["b"]
    @test ext(c, store_input=true).metadata == [""]
    @test ext(d, store_input=true).metadata == ["d"]
    @test ext(e, store_input=true).metadata == [""]
    @test ext(f, store_input=true).metadata == [5.2]
    @test ext(nothing, store_input=true).metadata == [nothing]
    #todo: add tests for all extractors for store_input=true
end

@testset "AuxiliaryExtractor" begin
    e2 = ExtractCategorical(["a","b"])
    e = AuxiliaryExtractor(e2, (ext, sample; store_input=false)->ext(String(sample); store_input))

    @test e("b") == e("bbb"[1:1])
    @test e("b").data ≈ [0, 1, 0]
    @test e("bbb"[1:1]).data ≈ [0, 1, 0]

    @test buf_printtree(e) ==
    """
    Auxiliary extractor with
      ╰── Categorical d = 3
    """
end

@testset "Not skipping single dict key" begin
    j1 = JSON.parse("""{"a": []}""")
    j2 = JSON.parse("""{"a": [1, 2]}""")
    j3 = JSON.parse("""{"a": [1, 2, 3]}""")
    j4 = JSON.parse("""{"a": [1, 2, 4, 5]}""")
    j5 = JSON.parse("""{"a": [1, 2, 3, 6, 7]}""")

    sch = JsonGrinder.schema([j1, j2, j3, j4, j5])
    ext = suggestextractor(sch, testing_settings)

    @test buf_printtree(ext) ==
    """
    Dict
      ╰── a: Array of
               ╰── Float32
    """

    ext_j2 = ext(j2)
    @test buf_printtree(ext_j2) ==
    """
    ProductNode  # 1 obs, 16 bytes
      ╰── a: BagNode  # 1 obs, 80 bytes
               ╰── ArrayNode(1×2 Array with Float32 elements)  # 2 obs, 56 bytes
    """

    m = reflectinmodel(sch, ext)
    @test buf_printtree(m) ==
    """
    ProductModel ↦ identity
      ╰── a: BagModel ↦ BagCount([SegmentedMean(1); SegmentedMax(1)]) ↦ Dense(3 => 10)  # 4 arrays, 42 params, 328 bytes
               ╰── ArrayModel(identity)
    """
end

@testset "default_scalar_extractor" begin

end

@testset "type stability of extraction missings" begin
    # todo: make tests for categorical, scalar, string, vector
    j1 = JSON.parse("""{"a": 1}""")
    j2 = JSON.parse("""{"b": "a"}""")
    j3 = JSON.parse("""{"a": 3, "b": "b"}""")
    j4 = JSON.parse("""{"a": 4, "b": "c"}""")
    j5 = JSON.parse("""{"a": 5, "b": "d"}""")

    sch = schema([j1,j2,j3,j4,j5])
    ext = suggestextractor(sch, testing_settings)
    m = reflectinmodel(sch, ext)

    e1 = ext(j1)
    e2 = ext(j2)
    e3 = ext(j3)
    e12 = catobs(e1, e2)
    e23 = catobs(e2, e3)
    e13 = catobs(e1, e3)
    @test typeof(e1) == typeof(e2)
    @test typeof(e1) == typeof(e3)
    @test typeof(e1) == typeof(e12)
    @test typeof(e1) == typeof(e23)
    @test typeof(e1) == typeof(e13)
end

@testset "Empty arrays" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j3 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j4 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")

	sch1 = JsonGrinder.schema([j1])
	sch2 = JsonGrinder.schema([j1,j2,j3])
	sch3 = JsonGrinder.schema([j2,j3,j1])

	@test sch1.updated == 1
	@test keys(sch1) == Set([:a])
	ext1 = suggestextractor(sch1)
	@test isnothing(ext1)

	@test sch2.updated == sch3.updated
	@test sch2[:a].l == sch3[:a].l
	@test sch2[:a].updated == sch3[:a].updated
	@test sch2[:a].items[:a].updated == sch3[:a].items[:a].updated
	@test sch2[:a].items[:a].counts == sch3[:a].items[:a].counts

	ext2 = suggestextractor(sch2)
	ext3 = suggestextractor(sch3)
	@test ext2 == ext3

	sch = JsonGrinder.schema([Dict("key" => []), Dict("key" => [1,2,3])])
	ext = suggestextractor(sch)
	@test ext[:key].item isa ExtractCategorical
end

@testset "More empty arrays" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b":[]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":[]}""")

	sch1 = JsonGrinder.schema([j1,j2])
	ext1 = suggestextractor(sch1)
	m = reflectinmodel(sch1, ext1)
	# todo: add tests that b is not there
	@test sch1.updated == 2
	@test sch1[:a].updated == 2
	@test :b ∈ keys(sch1)
	@test :b ∉ keys(ext1)
	@test :b ∉ keys(m)
end

@testset "Sample synthetic and make_representative_sample" begin
	@testset "basic without missing keys" begin
		sch = DictEntry(Dict(
			:a=>ArrayEntry(
				DictEntry(Dict(
					:a=>Entry(Dict(1=>4,2=>1), 5),
					:b=>Entry(Dict(1=>1,2=>2,3=>2), 5),
					),
				5),
				Dict(0=>1,1=>1,2=>2),
			4),
			:b=>Entry(Dict(1=>2,2=>2), 4),
			),
		4)
		@test sample_synthetic(sch) == Dict(
			:a=>[
				Dict(:a=>2,:b=>2),
				Dict(:a=>2,:b=>2)
			],
			:b=>2)
		ext = suggestextractor(sch)
		@test !ext[:a].item[:a].uniontypes
		@test !ext[:a].item[:b].uniontypes

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a, :b),
			Tuple{BagNode{
				ProductNode{NamedTuple{(:a, :b),
					Tuple{
						ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}},Nothing},
						ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}},Nothing}}
					},Nothing},
				AlignedBags{Int64},Nothing},
			ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}},Nothing}}
		}, Nothing}
	end

	@testset "basic with missing keys" begin
		sch = DictEntry(Dict(
			:a=>ArrayEntry(
				DictEntry(Dict(
					:a=>Entry(Dict(1=>3,2=>1), 4),
					:b=>Entry(Dict(2=>2,3=>2), 4),
					),
				5),
				Dict(0=>1,1=>1,2=>2),
			4),
			:b=>Entry(Dict(1=>2,2=>2), 4),
			),
		4)
		@test sample_synthetic(sch) == Dict(
			:a=>[
				Dict(:a=>2,:b=>2),
				Dict(:a=>2,:b=>2),
				],
			:b=>2
			)
		ext = suggestextractor(sch)
		@test ext[:a].item[:a].uniontypes
		@test ext[:a].item[:b].uniontypes
		@test !ext[:b].uniontypes

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a, :b),
			Tuple{BagNode{
				ProductNode{NamedTuple{(:a, :b),
					Tuple{
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}},Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}},Nothing}}
				},Nothing},AlignedBags{Int64},Nothing},
			ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}},Nothing}
		}},Nothing}
	end

	@testset "with missing keys in dict" begin
		sch = DictEntry(Dict(
			:a=>ArrayEntry(
				DictEntry(Dict(
					:a=>Entry(Dict("a"=>1,"b"=>1,"c"=>1,"d"=>1), 4),
					:b=>Entry(Dict(3=>1,2=>2), 3),
					:c=>Entry(Dict(1=>5), 5)
					),
				5),
				Dict(0=>1,1=>1,2=>2),
			4)),
		4)

		@test JsonGrinder.sample_synthetic(sch) == Dict(
			:a=>[Dict(:a=>"c",:b=>2,:c=>1), Dict(:a=>"c",:b=>2,:c=>1)]
		)

		ext = suggestextractor(sch)
		@test ext[:a].item[:a].uniontypes
		@test ext[:a].item[:b].uniontypes
		@test !ext[:a].item[:c].uniontypes
		# todo: add tests for extraction of synthetic samples and if they have correct types
		m = reflectinmodel(sch, ext)
		# now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a": [{"a":"a","c":1},{"b":2,"c":1}]}"""))) isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a": []}"""))) isa Matrix{Float32}

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a,),
			Tuple{BagNode{
				ProductNode{NamedTuple{(:a, :b, :c),
					Tuple{
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}, Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}, Nothing},
						ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}}, Nothing}
					}},
				Nothing},
			AlignedBags{Int64}, Nothing}}}, Nothing}
	end

	@testset "with missing nested dicts" begin
		sch = DictEntry(Dict(
			:a=>DictEntry(Dict(
					:a=>Entry(Dict("a"=>1,"b"=>1,"c"=>1), 3),
					:b=>Entry(Dict(3=>1), 1),
					:c=>Entry(Dict(1=>3), 3)),
				3),
			:b=>Entry(Dict(1=>4), 4)),
		4)
		@test sample_synthetic(sch) == Dict(
			:a=>Dict(:a=>"c",:b=>3,:c=>1), :b=>1
		)

		ext = suggestextractor(sch)

		@test ext[:a][:a].uniontypes
		@test ext[:a][:b].uniontypes
		@test ext[:a][:c].uniontypes
		@test !ext[:b].uniontypes

		# todo: add test for make_representative_sample
		m = reflectinmodel(sch, ext)
		# now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"b":1}"""))) isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a": {"a":"c","c":1},"b":1}"""))) isa Matrix{Float32}

		# now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a": [{"a":"a","c":1},{"b":2,"c":1}], "b": 1}"""))) isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a": [], "b": 1}"""))) isa Matrix{Float32}
		# the key b is always present, it should not be missing
		@test_throws ErrorException m(ext(JSON.parse("""{"a": []}""")))

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a, :b),
			Tuple{
				ProductNode{NamedTuple{(:a, :b, :c),
					Tuple{
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}, Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}, Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}}, Nothing}
					}},
				Nothing},
				ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}}, Nothing}
			}},
		Nothing}
	end

	@testset "with numbers and numeric strings" begin
		sch = DictEntry(Dict(
			:a=>InconsistentEntry([
				Entry(Dict(2=>1,5=>1), 2),
				Entry(Dict("4"=>1,"3"=>1), 2)],
			4),
			:b=>InconsistentEntry([
				Entry(Dict(2=>1,5=>1), 2),
				Entry(Dict("4"=>1), 1)],
			3)),
		4)

		@test sample_synthetic(sch) == Dict(:a=>5,:b=>5)

		ext = suggestextractor(sch)
		# this is broken, all samples are full, just once as a string, once as a number, it should not be uniontype
		@test !ext[:a][1].uniontypes
		@test ext[:b][1].uniontypes

		s = ext(sample_synthetic(sch))
		# this is wrong, check it
		@test s[:a][:e1].data ≃ [0 0 0 1 0]'
		@test s[:b][:e1].data ≃ [0 0 1 0]'

		m = reflectinmodel(sch, ext)
		@test !(m[:a][:e1].m isa PostImputingDense)
		@test m[:b][:e1].m isa PostImputingDense

		# # now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a":5}"""))) isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a":"3"}"""))) isa Matrix{Float32}

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a, :b),
			Tuple{
				ProductNode{NamedTuple{(:e1,),
					Tuple{ArrayNode{OneHotMatrix{UInt32, Vector{UInt32}},Nothing}}},
					Nothing},
				ProductNode{NamedTuple{(:e1,),
					Tuple{ArrayNode{MaybeHotMatrix{Union{Missing, UInt32}, Int, Union{Missing, Bool}},Nothing}}
					}, Nothing}
				}
			},Nothing}
	end


	@testset "with irregular schema, dict and scalars mixed" begin
		sch = DictEntry(Dict(
			:a=>InconsistentEntry([
				Entry(Dict(2=>1,5=>1), 2),
				DictEntry(Dict(
					:a=>Entry(Dict(3=>2), 1),
					:b=>Entry(Dict(1=>2), 2)),
				2),
				],
			4)),
		4)

		# this is not representative, but all information is inside types
		@test sample_synthetic(sch) == Dict(:a=>5)

		ext = suggestextractor(sch)
		# this is broken, all samples are full, just once as a string, once as a number, it should not be uniontype
		@test ext[:a][1].uniontypes
		@test ext[:a][2][:a].uniontypes
		@test ext[:a][2][:b].uniontypes

		s = ext(sample_synthetic(sch))
		# this is wrong, check it
		@test s[:a][:e1].data ≃ [0 1 0]'

		m = reflectinmodel(sch, ext)
		# this is wrong, it should not be postimputing
		@test m[:a][:e1].m isa PostImputingDense

		# # now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a":5}"""))) isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a":"3"}"""))) isa Matrix{Float32}
	end
	# todo: test schema with keyasfield
end

@testset "Fail empty bag extractor" begin
	ex = JsonGrinder.newentry([])
	@test isnothing(suggestextractor(ex))
end

