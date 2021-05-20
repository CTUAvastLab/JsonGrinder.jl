using JsonGrinder, JSON, Test, SparseArrays, Flux, Random, HierarchicalUtils
using JsonGrinder: ExtractScalar, ExtractCategorical, ExtractArray, ExtractDict, ExtractVector
using JsonGrinder: extractempty
using Mill
using Mill: catobs, nobs, MaybeHotMatrix
using Flux: OneHotMatrix
using LinearAlgebra

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
	    @test nobs(sc(missing)) == 1
	    @test nobs(sc(nothing)) == 1
	    @test sc(extractempty).data isa Matrix{Union{Missing, Float64}}
	    @test nobs(sc(extractempty)) == 0
	    @test nobs(sc(5)) == 1

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
		@test nobs(sc1(5)) == 1

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
    		@test nobs(sc1(extractempty)) == 0
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
		@test nobs(en.data) == 0
		@test en.data.data isa MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
		@test nobs(en.data.data) == 0
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
		@test nobs(sc(extractempty).data.data) == 0
		@test nobs(sc(extractempty).data) == 0
		@test isempty(sc(extractempty).bags.bags)
		@test sc(extractempty).data.data isa MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
		with_emptyismissing(true) do
			@test nobs(sc(extractempty)) == 0
		end
		with_emptyismissing(false) do
			@test nobs(sc(extractempty)) == 0
		end
	end
	sc = ExtractArray(ExtractScalar(Float32))
	e234 = sc([2,3,4], store_input=false)
	en = sc(nothing, store_input=false)
	e234s = sc([2,3,4], store_input=true)
	ens = sc(nothing, store_input=true)
	@test all(e234.data.data .== [2 3 4])
	@test nobs(en.data) == 0
	@test all(en.bags.bags .== [0:-1])
	@test nobs(sc(Dict(1=>1)).data) == 0

	@test nobs(sc(extractempty).data.data) == 0
	@test nobs(sc(extractempty).data) == 0
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
			@test nobs(sc1(extractempty).data) == 0
			@test nobs(sc1(extractempty)) == 0
			@test sc2(extractempty).data isa Matrix{Union{Missing, Int64}}
			@test nobs(sc2(extractempty).data) == 0
			@test nobs(sc2(extractempty)) == 0
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
			@test nobs(sc1(extractempty).data) == 0
			@test sc2(extractempty).data isa Matrix{Int64}
			@test nobs(sc2(extractempty).data) == 0
			@test sc3(extractempty).data isa Matrix{Float32}
			@test nobs(sc3(extractempty).data) == 0
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

	@testset "extractempty" begin
		a4 = br(extractempty)
		@test nobs(a4) == 0
		@test nobs(a4[:a]) == 0
		@test a4[:a].data isa Matrix{Union{Missing, Float64}}
		@test nobs(a4[:b]) == 0
		@test a4[:b].data isa Matrix{Union{Missing, Float64}}
		@test nobs(a4[:c]) == 0
		@test nobs(a4[:c].data) == 0
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
		@test nobs(a4) == 0
		@test nobs(a4[:a]) == 0
		@test nobs(a4[:a].data) == 0
		@test a4[:a].data.data isa Matrix{Union{Missing, Float32}}
		@test nobs(a4[:b]) == 0
		@test nobs(a4[:b].data) == 0
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
	@test typeof(ea.data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test typeof(en.data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test typeof(em.data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test e(extractempty).data isa MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test nobs(e(extractempty)) == 0

	@test e(["a", "b"]).data ≃ [missing missing missing]'
	@test mapreduce(e, catobs, ["a", "b"]).data ≈ [1 0; 0 1; 0 0]
	@test e(["a", missing]).data ≃ [missing missing missing]'
	@test mapreduce(e, catobs, ["a", missing]).data ≃ [true missing; false missing; false missing]
	@test e(["a", missing, "x"]).data ≃ [missing missing missing]'
	@test mapreduce(e, catobs, ["a", missing, "x"]).data ≃ [true missing false; false missing false; false missing true]
	@test typeof(e(["a", "b"]).data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test typeof(mapreduce(e, catobs, ["a", "b"]).data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test typeof(e(["a", "b", nothing]).data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}
	@test typeof(mapreduce(e, catobs, ["a", "b", nothing]).data) == MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}}

	@test catobs(ea, eb).data ≈ [1 0; 0 1; 0 0]
	@test reduce(catobs, [ea.data, eb.data]) ≈ [1 0; 0 1; 0 0]
	@test hcat(ea.data, eb.data) ≈ [1 0; 0 1; 0 0]
	@test e(Dict(1=>2)).data |> collect ≃ [missing missing missing]'

	@test catobs(eas, ebs).data == catobs(ea, eb).data
	@test reduce(catobs, [eas.data, ebs.data]) == reduce(catobs, [ea.data, eb.data])
	@test e(Dict(1=>2)).data ≃ [missing missing missing]'

	@test catobs(eas, ebs).metadata == ["a", "b"]
	@test e(Dict(1=>2), store_input=true).metadata == [Dict(1=>2)]

	@test nobs(ea) == 1
	@test nobs(eb) == 1
	@test nobs(ez) == 1
	@test nobs(en) == 1
	@test nobs(em) == 1
	@test nobs(em.data) == 1
	@test nobs(e([missing, nothing])) == 1
	@test nobs(mapreduce(e, catobs, [missing, nothing])) == 2
	@test nobs(e([missing, nothing, "a"])) == 1
	@test nobs(mapreduce(e, catobs, [missing, nothing, "a"])) == 3

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
	@test typeof(e("a").data) == OneHotMatrix{Int64, 3, Vector{Int64}}
	@test e(extractempty).data isa OneHotMatrix{Int64, 3, Vector{Int64}}
	@test nobs(e(extractempty)) == 0

	@test mapreduce(e, catobs, ["a", "b"]).data ≈ [1 0; 0 1; 0 0]
	@test_throws ErrorException e(["a", "b"]).data
	@test_throws ErrorException e(["a", missing])
	@test_throws ErrorException e(["a", missing, "x"])
	@test_throws ErrorException typeof(e(["a", "b"]).data)
	@test typeof(mapreduce(e, catobs, ["a", "b"]).data) == OneHotMatrix{Int64, 3, Vector{Int64}}
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

	@test nobs(e("a")) == 1
	@test nobs(e("b")) == 1
	@test nobs(e("z")) == 1
	@test_throws ErrorException nobs(e(nothing))
	@test_throws ErrorException nobs(e(missing))
	@test_throws ErrorException nobs(e([missing, nothing]))
	@test_throws ErrorException nobs(e([missing, nothing, "a"]))

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
end

@testset "ExtractString" begin
	e = ExtractString(true)
	ehello = e("Hello", store_input=false)
	ehellos = e("Hello", store_input=true)
	@test ehello.data.s == ["Hello"]
	@test ehello.data == ehellos.data
	@test e(Symbol("Hello")).data.s == ["Hello"]
	@test e(["Hello", "world"]).data.s ≃ [missing]
	@test mapreduce(e, catobs, ["Hello", "world"]).data.s == ["Hello", "world"]

	@test e(missing).data.s ≃ [missing]
	@test e(nothing).data.s ≃ [missing]
	@test isequal(e(Dict(1=>2)), e(missing))
	@test ehello isa ArrayNode{NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}},Nothing}
	@test ehello.data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
	@test e(missing).data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
	@test e(nothing).data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
	@test ehellos.metadata == ["Hello"]
	@test nobs(e(extractempty)) == 0

	e = ExtractString(false)
	@test e("Hello").data.s == ["Hello"]
	@test e(Symbol("Hello")).data.s == ["Hello"]
	@test_throws ErrorException e(["Hello", "world"]).data.s
	@test mapreduce(e, catobs, ["Hello", "world"]).data.s == ["Hello", "world"]
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
	@test b.data[:key].data.s[1] == k

	with_emptyismissing(true) do
		b = ext(nothing)
		@test nobs(b) == 1
		@test ismissing(b.data)
		b = ext(Dict())
		@test nobs(b) == 1
		@test ismissing(b.data)
	end
	with_emptyismissing(false) do
		b = ext(nothing)
		@test nobs(b) == 1
		@test nobs(b.data) == 0
		@test b.data[:key].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
		b = ext(Dict())
		@test nobs(b) == 1
		@test nobs(b.data) == 0
		@test b.data[:key].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}
	end

	b = ext(extractempty)
	@test nobs(b) == 0
	@test nobs(b.data) == 0
	@test nobs(b.data[:item]) == 0
	@test b.data[:item].data isa Matrix{Float32}
	@test nobs(b.data[:key]) == 0
	@test b.data[:key].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}

	js = [Dict(randstring(5) => Dict("a" => rand(), "b" => randstring(1))) for _ in 1:1000]
	sch = JsonGrinder.schema(js)
	ext = JsonGrinder.suggestextractor(sch, (;key_as_field = 500))

	b = ext(js[1])
	k = only(keys(js[1]))
	i = ext.item(js[1][k])
	@test b.data[:item][:a].data == i[:a].data
	@test b.data[:item][:b].data == i[:b].data
	@test b.data[:key].data.s[1] == k
	@test isnothing(b.data[:key].metadata)
	@test isnothing(b.data[:item][:a].metadata)
	@test isnothing(b.data[:item][:b].metadata)

	b = ext(nothing)
	@test nobs(b) == 1
	@test nobs(b.data) == 0
	b = ext(Dict())
	@test nobs(b) == 1
	@test nobs(b.data) == 0

	b = ext(js[1], store_input=true)
	k = only(keys(js[1]))
	@test b.data[:key].metadata == [k]
	@test b.data[:item][:a].metadata == fill(js[1][k]["a"],1,1)
	@test b.data[:item][:b].metadata == [js[1][k]["b"]]

	b = ext(Dict(), store_input=true)
	@test b.metadata == [Dict()]
	@test isnothing(b.data[:key].metadata)
	@test isnothing(b.data[:item].metadata)

	b = ext(nothing, store_input=true)
	@test b.metadata == [nothing]
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
	@test buf_printtree(m) == """
	ProductModel … ↦ ArrayModel(Dense(52, 10))
	  ├── a: ArrayModel(Dense(6, 10))
	  ├── b: ArrayModel(Dense(2053, 10))
	  ├── c: ArrayModel(Dense(5, 10))
	  ├── d: ArrayModel(identity)
	  ├── e: ArrayModel(Dense(4, 10))
	  ├── f: ArrayModel(Dense(4, 10))
	  └── g: ArrayModel(identity)
	"""
end

# todo: add separate tests for reflectinmodel(sch, ext) to test behavior with various missing and non-missing stuff in schema
# e.g. empty string, missing keys, irregular schema and MultiRepresentation

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
	@test ext[:c] isa ExtractArray{ExtractCategorical{Number,Int64}}

	@test buf_printtree(ext, trav=true) ==
	"""
	Dict [""]
	  ├── a: Float32 ["E"]
	  ├── b: FeatureVector with 3 items ["U"]
	  └── c: Array of ["k"]
	           └── Categorical d = 6 ["s"]
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
	@test ismissing(a[:a][:e2].data[:a].data.s[1])
	@test nobs(a[:a][:e3]) == 1
	@test nobs(a[:a][:e3].data) == 1
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
	@test sch_hash == hash(sch)	# testing that my entry parkour does not modify schema
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
	[Dict] (updated = 7)
	  └── a: [MultiEntry] (updated = 7)
	           ├── 1: [Scalar - String], 3 unique values, updated = 3
	           ├── 2: [Scalar - Float64,Int64], 2 unique values, updated = 2
	           ├── 3: [List] (updated = 1)
	           │        └── [Scalar - Int64], 5 unique values, updated = 5
	           └── 4: [Dict] (updated = 1)
	                    └── Sylvanas is the worst warchief ever: [Scalar - String], 1 unique values, updated = 1
	"""

	@test buf_printtree(ext, trav=true) ==
    """
	Dict [""]
	  └── a: MultiRepresentation ["U"]
	           ├── e1: FeatureVector with 5 items ["c"]
	           ├── e2: Dict ["k"]
	           │         └── Sylvanas is the worst warchief ever: String ["o"]
	           └── e3: Float32 ["s"]
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
	ProductNode with 1 obs
	  └── a: ProductNode with 1 obs
	           ├── e1: ArrayNode(5×1 Array with Union{Missing, Float32} elements) with 1 obs
	           ├── e2: ProductNode with 1 obs
	           │         └── Sylvanas is the worst warchief ever: ArrayNode(2053×1 NGramMatrix with Union{Missing, Int64} elements) with 1 obs
	           └── e3: ArrayNode(1×1 Array with Union{Missing, Float32} elements) with 1 obs
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
	[Dict] (updated = 5)
	  └── a: [MultiEntry] (updated = 5)
	           ├── 1: [Scalar - String], 2 unique values, updated = 2
	           ├── 2: [Scalar - Float64,Int64], 2 unique values, updated = 2
	           └── 3: [List] (updated = 1)
	                    └── [Scalar - Int64], 5 unique values, updated = 5
	"""

	@test buf_printtree(ext) ==
	"""
	Dict
	  └── a: MultiRepresentation
	           ├── e1: String
	           ├── e2: Float32
	           └── e3: FeatureVector with 5 items
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
	@test all(ext(f).data.s .=== ext(nothing).data.s)

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

	@test e("b") == e(:b)
	@test e("b").data ≈ [0, 1, 0]
	@test e(:b).data ≈ [0, 1, 0]

    @test buf_printtree(e) ==
	"""
	Auxiliary extractor with
	  └── Categorical d = 3
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
	  └── a: Array of
	           └── Float32
	"""

	ext_j2 = ext(j2)
	@test buf_printtree(ext_j2) ==
    """
	ProductNode with 1 obs
	  └── a: BagNode with 1 obs
	           └── ArrayNode(1×2 Array with Float32 elements) with 2 obs
	"""

	m = reflectinmodel(sch, ext)
	@test buf_printtree(m) ==
    """
	ProductModel … ↦ ArrayModel(identity)
	  └── a: BagModel … ↦ [SegmentedMean(1); SegmentedMax(1)] ↦ ArrayModel(Dense(2, 10))
	           └── ArrayModel(identity)
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
	typeof(e1)
	typeof(e2)
	typeof(e3)
	typeof(e12)
	typeof(e23)
	typeof(e13)
	@test typeof(e1) == typeof(e2)
	@test typeof(e1) == typeof(e3)
	@test typeof(e1) == typeof(e12)
	@test typeof(e1) == typeof(e23)
	@test typeof(e1) == typeof(e13)
end
