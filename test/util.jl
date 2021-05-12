using Setfield, Flux, InteractiveUtils

@testset "code2lens & lens2code" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2,"c":"oh"}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3,"c":"hi"},{"b":2,"a":1,"c":"Mark"}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4, j5])
	ext = suggestextractor(sch)

    for t in list_traversal(sch)
        @test all(l -> all(t .== lens2code(sch, l)), code2lens(sch, t))
    end
    for t in list_traversal(ext)
        @test all(l -> all(t .== lens2code(ext, l)), code2lens(ext, t))
    end

	l_sch = code2lens(sch, "w") |> only
	l_ext = code2lens(ext, "w") |> only
	@test l_sch == (@lens _.childs[:a].items.childs[:c])
	@test l_ext == (@lens _.dict[:a].item.dict[:c])
	@test get(sch, l_sch) == sch["w"]
	@test get(ext, l_ext) == ext["w"]
	@test lens2code(sch, l_sch) |> only == "w"
	@test lens2code(ext, l_ext) |> only == "w"

	j1 = JSON.parse("""{"a": 4, "b": "birb"}""")
	j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}, "b": "bird"}""")
	j3 = JSON.parse("""{"a": [1, 2, 3, "hi"], "b": "word"}""")

	sch = schema([j1, j2, j3])
	l_sch = code2lens(sch, "S") |> only
	@test l_sch == (@lens _.childs[:a].childs[3].items)
end

@testset "onehot hcat" begin
	X1 = Flux.onehotbatch([1,2,3,4,5], 1:10)
	@test @which(hcat(X1,X1)).module == JsonGrinder
	@test @which(reduce(hcat, [X1,X1])).module == JsonGrinder

	@test hcat(X1,X1) == Flux.onehotbatch([1,2,3,4,5,1,2,3,4,5], 1:10)
	@test reduce(hcat, [X1,X1]) == Flux.onehotbatch([1,2,3,4,5,1,2,3,4,5], 1:10)

	X2 = Flux.onehotbatch([1,2,3,4,5,6], 1:12)
	@test_throws DimensionMismatch hcat(X1,X2)
end
