using Mill, JSON, BSON, Flux, JsonGrinder, Test, HierarchicalUtils
using JsonGrinder: suggestextractor, schema, sample_synthetic, make_representative_sample
using JsonGrinder: DictEntry, Entry, MultiEntry, ArrayEntry
using Mill: reflectinmodel

@testset "Basic behavior testing" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])

	@test sch[:a].counts == Dict(4 => 4)
	@test sch[:a].updated == 4
	@test sch[:b].updated == 4
	@test sch[:b][:a].updated == 2
	@test sch[:b][:a].l == Dict(3 => 2)
	@test sch[:b][:a].items.counts == Dict(1 => 2, 2 => 2, 3 => 2)
	@test sch[:b][:a].items.updated == 6
	@test sch[:b][:b].counts == Dict(1 => 2)
	@test sch[:b][:b].updated == 2
	@test sch[:c].updated == 2
	@test sch[:c][:a].updated == 2
	@test sch[:c][:a][:a].updated == 2
	@test sch[:c][:a][:a].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:a].items.counts == Dict(1 => 1, 2 => 2, 3 => 2)
	@test sch[:c][:a][:a].items.updated == 5
	@test sch[:c][:a][:b].updated == 2
	@test sch[:c][:a][:b].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:b].items.counts == Dict(4 => 1, 5 => 2, 6 => 2)
	@test sch[:c][:a][:b].items.updated == 5

	@test keys(sch[:a]) == [4]
end

@testset "Empty string vs missing key testing" begin
	j1 = JSON.parse("""{"a": "b", "b": ""}""")
	j2 = JSON.parse("""{"a": "a", "b": "c"}""")
	sch1 = JsonGrinder.schema([j1,j2])
	@test sch1[:a].updated == 2
	@test sch1[:b].updated == 2
	@test sch1.updated == 2

	j1 = JSON.parse("""{"a": "b"}""")
	j2 = JSON.parse("""{"a": "a", "b": "c"}""")
	sch2 = JsonGrinder.schema([j1,j2])
	@test sch2[:a].updated == 2
	@test sch2[:b].updated == 1
	@test sch2.updated == 2

	ext1 = suggestextractor(sch1)
	ext2 = suggestextractor(sch2)

	m1 = reflectinmodel(sch1, ext1)
	m2 = reflectinmodel(sch2, ext2)

	@test m1[:b].m isa Dense
	@test m1[:b].m.weight isa Matrix
	@test m2[:b].m isa PostImputingDense
	@test m2[:b].m.weight isa PostImputingMatrix
	@test buf_printtree(m1) != buf_printtree(m2)
end

@testset "Irregular schema" begin
	j1 = JSON.parse("""{"a": 4}""")
	j2 = JSON.parse("""{"a": { "a": "hello", "b":[5,6]}}""")
	j3 = JSON.parse("""{"a": [1, 2, 3 , 4]}""")
	# todo: add tests for array and empty dict, and which extractors it generates
	# basically test sth. like this
	# j1 = JSON.parse("""{"a": 4, "b": [{"a":[1,2,3],"b": 1}],"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	# j2 = JSON.parse("""{"a": 4, "c": {"a": {"a":[2,3],"b":[5,6]}}}""")
	# j3 = JSON.parse("""{"a": 4, "b": [{"a":[1,2,3],"b": 1}]}""")
	# j4 = JSON.parse("""{"a": 4, "b": [{}]}""")
	# j5 = JSON.parse("""{"b": {}}""")
	# j6 = JSON.parse("""{}""")

	sch = JsonGrinder.DictEntry()
	JsonGrinder.update!(sch, j1)
	@test typeof(sch[:a]) <: Entry
	JsonGrinder.update!(sch, j2)
	JsonGrinder.update!(sch, j3)
	@test typeof(sch[:a]) <: MultiEntry
	@test typeof(sch[:a][1]) <: Entry
	@test typeof(sch[:a][2]) <: DictEntry
	@test typeof(sch[:a][3]) <: ArrayEntry

	jsons = [j1, j2, j3]
	types = [Entry, DictEntry, ArrayEntry]
	for ii in [[1,2,3], [3,2,1], [2,3,1],[2,1,3] , [1,3,2]]
		sch = JsonGrinder.DictEntry()
		JsonGrinder.update!(sch, jsons[ii[1]])
		@test typeof(sch[:a]) <: types[ii[1]]
		JsonGrinder.update!(sch, jsons[ii[2]])
		JsonGrinder.update!(sch, jsons[ii[3]])
		@test typeof(sch[:a]) <: MultiEntry
		@test typeof(sch[:a][1]) <: types[ii[1]]
		@test typeof(sch[:a][2]) <: types[ii[2]]
		@test typeof(sch[:a][3]) <: types[ii[3]]
	end

	jsons = [Dict("a" => [j["a"]]) for j in jsons]
	for ii in [[1,2,3], [3,2,1], [2,3,1],[2,1,3] , [1,3,2]]
		sch = JsonGrinder.DictEntry()
		JsonGrinder.update!(sch, jsons[ii[1]])
		@test typeof(sch[:a]) <: ArrayEntry
		@test typeof(sch[:a].items) <: types[ii[1]]
		JsonGrinder.update!(sch, jsons[ii[2]])
		JsonGrinder.update!(sch, jsons[ii[3]])
		@test typeof(sch[:a].items)  <: MultiEntry
		@test typeof(sch[:a].items[1]) <: types[ii[1]]
		@test typeof(sch[:a].items[2]) <: types[ii[2]]
		@test typeof(sch[:a].items[3]) <: types[ii[3]]
	end

	j1 = JSON.parse("""{"a": 4}""")
	j2 = JSON.parse("""{"a": "hello"}""")
	sch = JsonGrinder.DictEntry()
	JsonGrinder.update!(sch, j1)
	@test typeof(sch[:a]) <: Entry
	JsonGrinder.update!(sch, j2)

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

@testset "Empty Arrays with multientry" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b":[]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":{}}""")
	j3 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":1}""")
	j4 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":"string"}""")

	sch1 = JsonGrinder.schema([j1,j2,j3,j4])
	ext1 = suggestextractor(sch1)
	m = reflectinmodel(sch1, ext1)
	# todo: add tests that b is not there
	@test [1,2,3,4] == keys(sch1[:b])
	@test (:e1, :e2) == keys(ext1[:b])
	@test (:e1, :e2) == keys(m[:b])
end

@testset "Schema merging" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")
	j6 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}], "b": 1}""")

	# todo: test how newentry works with array with multiple elements
	sch1 = JsonGrinder.schema([j1,j2,j3])
	sch2 = JsonGrinder.schema([j4,j5,j6])

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	sch_merged = merge(sch1, sch2)

	@test sch.updated == sch_merged.updated
	@test sch[:a].updated == sch_merged[:a].updated
	@test sch[:a].l == sch_merged[:a].l
	@test sch[:a].items[:a].updated == sch_merged[:a].items[:a].updated
	@test sch[:a].items[:a].counts == sch_merged[:a].items[:a].counts
	@test sch[:a].items[:b].updated == sch_merged[:a].items[:b].updated
	@test sch[:a].items[:b].counts == sch_merged[:a].items[:b].counts
	@test sch[:b].updated == sch_merged[:b].updated
	@test sch[:b].counts == sch_merged[:b].counts
end

@testset "Schema merging with numbers" begin
	j1 = JSON.parse("""{"a": 1}""")
	j2 = JSON.parse("""{"a": 2}""")
	j3 = JSON.parse("""{"a": 3.3}""")
	j4 = JSON.parse("""{"a": 4.4}""")
	j5 = JSON.parse("""{"a": "5"}""")
	j6 = JSON.parse("""{"a": "6"}""")
	j7 = JSON.parse("""{"a": "7.7"}""")
	j8 = JSON.parse("""{"a": "8.8"}""")

	# todo: test how newentry works with array with multiple elements
	sch12 = JsonGrinder.schema([j1,j2])
	sch34 = JsonGrinder.schema([j3,j4])
	sch56 = JsonGrinder.schema([j5,j6])
	sch78 = JsonGrinder.schema([j7,j8])

	sch1234 = JsonGrinder.schema([j1,j2,j3,j4])
	sch5678 = JsonGrinder.schema([j5,j6,j7,j8])
	sch1256 = JsonGrinder.schema([j1,j2,j5,j6])
	sch3478 = JsonGrinder.schema([j3,j4,j7,j8])

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8])
	sch_merged1234 = merge(sch12, sch34)
	sch_merged5678 = merge(sch56, sch78)
	sch_merged1256 = merge(sch12, sch56)
	sch_merged3478 = merge(sch34, sch78)
	sch_merged = merge(sch_merged1234, sch_merged5678)
	@test sch1234 == sch_merged1234
	@test sch1234 != sch_merged5678
	@test sch5678 == sch_merged5678
	@test sch1256 == sch_merged1256
	@test sch3478 == sch_merged3478
	@test sch == sch_merged
end

@testset "Bson and symbol keys testing" begin
	function bson_buffer(data)
		b = IOBuffer()
		BSON.bson(b, data)
		seek(b, 0)
	end

	b1 = bson_buffer(Dict(:a=>4,:b=>Dict(:a=>[1,2,3], :b=>1), :c=>Dict(:a=>Dict(:a=>[1,2,3],:b=>[4,5,6]))))
	b2 = bson_buffer(Dict(:a=>4,:c=>Dict(:a=>Dict(:a=>[2,3],:b=>[5,6]))))
	b3 = bson_buffer(Dict(:a=>4,:b=>Dict(:a=>[1,2,3],:b=>1)))
	b4 = bson_buffer(Dict(:a=>4,:b=>Dict()))
	b5 = bson_buffer(Dict(:b=>Dict()))
	b6 = bson_buffer(Dict())
	bs = [BSON.BSONDict(BSON.load(b)) for b in [b1,b2,b3,b4,b5,b6]]
	sch = JsonGrinder.schema(bs)

	@test sch[:a].counts == Dict(4 => 4)
	@test sch[:a].updated == 4
	@test sch[:b].updated == 4
	@test sch[:b][:a].updated == 2
	@test sch[:b][:a].l == Dict(3 => 2)
	@test sch[:b][:a].items.counts == Dict(1 => 2, 2 => 2, 3 => 2)
	@test sch[:b][:a].items.updated == 6
	@test sch[:b][:b].counts == Dict(1 => 2)
	@test sch[:b][:b].updated == 2
	@test sch[:c].updated == 2
	@test sch[:c][:a].updated == 2
	@test sch[:c][:a][:a].updated == 2
	@test sch[:c][:a][:a].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:a].items.counts == Dict(1 => 1, 2 => 2, 3 => 2)
	@test sch[:c][:a][:a].items.updated == 5
	@test sch[:c][:a][:b].updated == 2
	@test sch[:c][:a][:b].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:b].items.counts == Dict(4 => 1, 5 => 2, 6 => 2)
	@test sch[:c][:a][:b].items.updated == 5
end

@testset "Equals and hash test" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j3 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j4 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")

	sch0 = JsonGrinder.DictEntry()
	sch1 = JsonGrinder.schema([j1, j2, j3, j4])
	sch2 = JsonGrinder.schema([j1, j2, j3, j4])
	sch3 = JsonGrinder.schema([j1, j2, j3])

	@test hash(sch1) === hash(sch2)
	@test hash(sch1) !== hash(sch3)
	@test hash(sch1) !== hash(sch0)
	@test hash(sch3) !== hash(sch0)

	@test sch1 == sch2
	@test sch1 != sch3
	@test sch1 != sch0
	@test sch3 != sch0
end

@testset "Schema merging with max keys" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")
	j6 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":1}""")
	j7 = JSON.parse("""{"a": [{"a":4,"b":5},{"b":6,"a":7}], "b":2}""")
	j8 = JSON.parse("""{"a": [{"a":9,"b":10},{"b":11,"a":12}], "b":2}""")
	j9 = JSON.parse("""{"a": [{"a":4,"b":3},{"b":2,"a":2}], "b":2}""")
	j10 = JSON.parse("""{"a": [{"a":11,"b":12},{"b":13,"a":14}], "b":2}""")
	j11 = JSON.parse("""{"a": [{"a":7,"b":5},{"b":6,"a":6}], "b":2}""")

	prev_keys = JsonGrinder.max_keys
	JsonGrinder.updatemaxkeys!(6)
	# todo: test how newentry works with array with multiple elements
	sch1 = JsonGrinder.schema([j1,j2,j3,j4,j5,j11])
	sch2 = JsonGrinder.schema([j6,j7,j8,j9,j10])

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8,j9,j10,j11])
	sch_merged = merge(sch1, sch2)

	@test sch == sch_merged
	JsonGrinder.updatemaxkeys!(prev_keys)
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
						ArrayNode{OneHotMatrix{Int64, 3, Vector{Int64}},Nothing},
						ArrayNode{OneHotMatrix{Int64, 4, Vector{Int64}},Nothing}}
					},Nothing},
				AlignedBags{Int64},Nothing},
			ArrayNode{OneHotMatrix{Int64, 3, Vector{Int64}},Nothing}}
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
						ArrayNode{MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}},Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}},Nothing}}
				},Nothing},AlignedBags{Int64},Nothing},
			ArrayNode{OneHotMatrix{Int64, 3, Vector{Int64}},Nothing}
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
		@test m(ext(JSON.parse("""{"a": [{"a":"a","c":1},{"b":2,"c":1}]}"""))).data isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a": []}"""))).data isa Matrix{Float32}

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a,),
			Tuple{BagNode{
				ProductNode{NamedTuple{(:a, :b, :c),
					Tuple{
						ArrayNode{NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}},Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}},Nothing},
						ArrayNode{OneHotMatrix{Int64, 2, Vector{Int64}},Nothing}
					}},
				Nothing},
			AlignedBags{Int64},Nothing}}},Nothing}
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
		@test m(ext(JSON.parse("""{"b":1}"""))).data isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a": {"a":"c","c":1},"b":1}"""))).data isa Matrix{Float32}

		# now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a": [{"a":"a","c":1},{"b":2,"c":1}], "b": 1}"""))).data isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a": [], "b": 1}"""))).data isa Matrix{Float32}
		# the key b is always present, it should not be missing
		@test_throws ErrorException m(ext(JSON.parse("""{"a": []}""")))

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a, :b),
			Tuple{
				ProductNode{NamedTuple{(:a, :b, :c),
					Tuple{
						ArrayNode{NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}},Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}},Nothing},
						ArrayNode{MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}},Nothing}
					}},
				Nothing},
				ArrayNode{OneHotMatrix{Int64, 2, Vector{Int64}},Nothing}
			}},
		Nothing}
	end

	@testset "with numbers and numeric strings" begin
		sch = DictEntry(Dict(
			:a=>MultiEntry([
				Entry(Dict(2=>1,5=>1), 2),
				Entry(Dict("4"=>1,"3"=>1), 2)],
			4),
			:b=>MultiEntry([
				Entry(Dict(2=>1,5=>1), 2),
				Entry(Dict("4"=>1), 1)],
			3)),
		4)

		@static if VERSION >= v"1.6.0-"
			@test sample_synthetic(sch) == Dict(:a=>5,:b=>5)
		else
			@test sample_synthetic(sch) == Dict(:a=>2,:b=>2)
		end

		ext = suggestextractor(sch)
		# this is broken, all samples are full, just once as a string, once as a number, it should not be uniontype
		@test !ext[:a][1].uniontypes
		@test ext[:b][1].uniontypes

		s = ext(sample_synthetic(sch))
		# this is wrong
		@static if VERSION >= v"1.6.0-"
			@test s[:a][:e1].data ≃ [0 0 0 1 0]'
			@test s[:b][:e1].data ≃ [0 0 1 0]'
		else
			@test s[:a][:e1].data ≃ [1 0 0 0 0]'
			@test s[:b][:e1].data ≃ [1 0 0 0]'
		end

		m = reflectinmodel(sch, ext)
		@test !(m[:a][:e1].m isa PostImputingDense)
		@test m[:b][:e1].m isa PostImputingDense

		# # now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a":5}"""))).data isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a":"3"}"""))).data isa Matrix{Float32}

		s = make_representative_sample(sch, ext)
		@test s isa ProductNode{NamedTuple{(:a, :b),
			Tuple{
				ProductNode{NamedTuple{(:e1,),
					Tuple{ArrayNode{OneHotMatrix{Int64, 5, Vector{Int64}},Nothing}}},
					Nothing},
				ProductNode{NamedTuple{(:e1,),
					Tuple{ArrayNode{MaybeHotMatrix{Union{Missing, Int64}, Int64, Union{Missing, Bool}},Nothing}}
					},Nothing}
				}
			},Nothing}
	end


	@testset "with irregular schema, dict and scalars mixed" begin
		sch = DictEntry(Dict(
			:a=>MultiEntry([
				Entry(Dict(2=>1,5=>1), 2),
				DictEntry(Dict(
					:a=>Entry(Dict(3=>2), 1),
					:b=>Entry(Dict(1=>2), 2)),
				2),
				],
			4)),
		4)

		# this is not representative, but all information is inside types
		@static if VERSION >= v"1.6.0-"
			@test sample_synthetic(sch) == Dict(:a=>5)
		else
			@test sample_synthetic(sch) == Dict(:a=>2)
		end

		ext = suggestextractor(sch)
		# this is broken, all samples are full, just once as a string, once as a number, it should not be uniontype
		@test ext[:a][1].uniontypes
		@test ext[:a][2][:a].uniontypes
		@test ext[:a][2][:b].uniontypes

		s = ext(sample_synthetic(sch))
		# this is wrong
		@static if VERSION >= v"1.6.0-"
			@test s[:a][:e1].data ≃ [0 1 0]'
		else
			@test s[:a][:e1].data ≃ [1 0 0]'
		end

		m = reflectinmodel(sch, ext)
		# this is wrong, it should not be postimputing
		@test m[:a][:e1].m isa PostImputingDense

		# # now I test that all outputs are numbers. If some output was missing, it would mean model does not have imputation it should have
		@test m(ext(JSON.parse("""{"a":5}"""))).data isa Matrix{Float32}
		@test m(ext(JSON.parse("""{"a":"3"}"""))).data isa Matrix{Float32}
	end
	# todo: test schema with keyasfield
end

@testset "Merge empty lists" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b": []}""")
	j2 = JSON.parse("""{"a": [{"a":3},{"b":4}], "b": []}""")
	j3 = JSON.parse("""{"a": [{"a":1},{"b":3}], "b": []}""")
	j4 = JSON.parse("""{"a": [{"a":2},{"b":4}], "b": [1]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	sch123 = JsonGrinder.schema([j1, j2, j3])
	sch12 = JsonGrinder.schema([j1, j2])
	sch3 = JsonGrinder.schema([j3])
	sch4 = JsonGrinder.schema([j4])
	sch_merged123 = merge(sch12, sch3)
	sch_merged1234 = merge(sch12, sch3, sch4)
	@test sch == sch_merged1234
	@test sch123 == sch_merged123
end

@testset "Symmetry" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b": []}""")
	j2 = JSON.parse("""{"a": [{"a":3},{"b":4}], "b": [1]}""")
	j3 = JSON.parse("""{"a": [{"a":1},{"b":3}], "b": []}""")

	sch1 = JsonGrinder.schema([j1, j2, j3])
	sch2 = JsonGrinder.schema([j2, j1, j3])
	sch3 = JsonGrinder.schema([j3, j2, j1])
	sch4 = JsonGrinder.schema([j1, j3, j2])
	@test sch1 == sch2
	@test sch1 == sch3
	@test sch2 == sch3
end

@testset "Fail empty bag extractor" begin
	ex = JsonGrinder.newentry([])
	@test isnothing(suggestextractor(ex))
end

@testset "Delete in path" begin
	j1 = JSON.parse("""{"a": 4, "b": [{"a":[1,2,3],"b": 1}],"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": {"a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": [{"a":[1,2,3],"b": 1}]}""")
	j4 = JSON.parse("""{"a": 4, "b": [{}]}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	@test children(sch[:c][:a]) == [:a=>sch[:c][:a][:a], :b=>sch[:c][:a][:b]]
	delete!(sch, ".c.a", "a")
	@test children(sch[:c][:a]) == [:b=>sch[:c][:a][:b]]
	@test children(sch[:b][1].items) == [:a=>sch[:b][1].items[:a], :b=>sch[:b][1].items[:b]]
	delete!(sch, ".b.1.[]", "a")
	@test children(sch[:b][1].items) == [:b=>sch[:b][1].items[:b]]

	suggestextractor(sch)
	# todo: add tests for this is identity is used for single-keyed multi-entry
	# todo: test indentity for multiple nested single-keyed dicts
end

@testset "Extractor from schema" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": {"a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	ext = suggestextractor(sch, testing_settings)

	@test ext[:a] isa ExtractCategorical
	@test ext[:b][:a] isa ExtractVector{Float32}
	@test ext[:b][:b] isa ExtractScalar{Float32}
	@test ext[:c][:a][:a] isa ExtractArray{ExtractScalar{Float32}}
	@test ext[:c][:a][:b] isa ExtractArray{ExtractScalar{Float32}}

	e1 = ext(j1)
	@test e1[:a].data ≈ [1, 0]
	@test e1[:b][:a].data ≈ [1, 2, 3]
	@test e1[:b][:b].data ≈ [0]
	@test e1[:c][:a][:a].data.data ≈ [0. 0.5 1.]
	@test e1[:c][:a][:b].data.data ≈ [0. 0.5 1.]
end

@testset "Mixing substrings with strings" begin
	a, b = split("a b")
	sch = JsonGrinder.schema([Dict("k" => a), Dict("k" => b), Dict("k" => "a"), Dict("k" => "b")])
	@test sch.childs[:k].counts == Dict("a"=>2, "b"=>2)
end

@testset "Merge inplace" begin
	j1 = JSON.parse("""{"a": 1}""")
	j2 = JSON.parse("""{"a": 2}""")
	j3 = JSON.parse("""{"a": 3}""")
	j4 = JSON.parse("""{"a": 1}""")
	j5 = JSON.parse("""{"a": 2}""")
	j6 = JSON.parse("""{"a": 3}""")

	# todo: test how newentry works with array with multiple elements
	sch1 = JsonGrinder.schema([j1,j2,j3])
	sch2 = JsonGrinder.schema([j4,j5,j6])
	sch1[:a]
	sch2[:a]
	@test sch1[:a].counts == Dict(2=>1,3=>1,1=>1)
	@test sch1[:a].updated == 3
	@test sch2[:a].counts == Dict(2=>1,3=>1,1=>1)
	@test sch2[:a].updated == 3
	JsonGrinder.merge_inplace!(sch1[:a], sch2[:a])
	@test sch1[:a].counts == Dict(2=>2,3=>2,1=>2)
	@test sch1[:a].updated == 6
end

@testset "Merging of irregular schemas" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")
	j6 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":1}""")
	j7 = JSON.parse("""{"a": [{"a":4,"b":5},{"b":6,"a":7}], "b":2}""")
	j8 = JSON.parse("""{"a": [{"a":9,"b":10},{"b":11,"a":12}], "b":2}""")
	j9 = JSON.parse("""{"a": 4, "b":2}""")
	j10 = JSON.parse("""{"a": 11, "b":2}""")
	j11 = JSON.parse("""{"a": 7, "b":2}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8,j9,j10,j11])
	sch11 = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	sch12 = JsonGrinder.schema([j7,j8,j9])
	sch13 = JsonGrinder.schema([j10,j11])
	sch21 = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8])
	sch22 = JsonGrinder.schema([j9,j10,j11])
	sch31 = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j9])
	sch32 = JsonGrinder.schema([j8,j10])
	sch33 = JsonGrinder.schema([j11,j7])

	sch1 = merge(sch11, sch12, sch13)
	sch2 = merge(sch21, sch22)
	sch3 = merge(sch31, sch32, sch33)

	@test sch == sch1
	@test sch == sch2
	@test sch == sch3

	@test hash(sch) === hash(sch1)
	@test hash(sch) === hash(sch2)
	@test hash(sch) === hash(sch3)
end

@testset "Merging strings with numbers" begin
	j1 = JSON.parse("""{"a": "4", "b": "2"}""")
	j2 = JSON.parse("""{"a": "11", "b": "2"}""")
	j3 = JSON.parse("""{"a": 7, "b": "3"}""")
	j4 = JSON.parse("""{"a": 4, "b": 3}""")
	j5 = JSON.parse("""{"a": "11", "b": 3}""")
	j6 = JSON.parse("""{"a": "7", "b": 4}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	sch11 = JsonGrinder.schema([j1,j2])
	sch12 = JsonGrinder.schema([j3,j4])
	sch13 = JsonGrinder.schema([j5,j6])
	sch21 = JsonGrinder.schema([j1,j2,j3])
	sch22 = JsonGrinder.schema([j4,j5,j6])

	sch1 = merge(sch11, sch12, sch13)
	sch2 = merge(sch21, sch22)

	@test sch == sch1
	@test sch == sch2

	@test hash(sch) === hash(sch1)
	@test hash(sch) === hash(sch2)
end

@testset "Schema merging with max keys and irregularities" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": [1, 2, 3, 4, 5, 6, 7]}""")
	j5 = JSON.parse("""{}""")
	j6 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":2}], "b":4}""")
	j7 = JSON.parse("""{"a": [{"a":4,"b":5},{"b":6,"a":7}], "b":2}""")
	j8 = JSON.parse("""{"a": [{"a":9,"b":10},{"b":11,"a":12}], "b":"1"}""")
	j9 = JSON.parse("""{"a": [{"a":4,"b":3},{"b":2,"a":1}], "b":"2"}""")
	j10 = JSON.parse("""{"a": [{"a":11,"b":12},{"b":13,"a":"14"}], "b":"3"}""")
	j11 = JSON.parse("""{"a": [{"a":7,"b":5},{"b":6,"a":"6"}], "b":"4"}""")

	prev_keys = JsonGrinder.max_keys
	JsonGrinder.updatemaxkeys!(4)
	# todo: test how newentry works with array with multiple elements
	sch1 = JsonGrinder.schema([j1,j2,j3,j4,j5,j11])
	sch2 = JsonGrinder.schema([j6,j7,j8,j9,j10])

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8,j9,j10,j11])
	sch_merged = merge(sch1, sch2)

	@test sch == sch_merged
	JsonGrinder.updatemaxkeys!(prev_keys)
end

@testset "Schema with string shortening" begin
	j1 = JSON.parse("""{"a": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}""")
	j2 = JSON.parse("""{"a": "b"}""")
	j3 = JSON.parse("""{"a": "🅱️"}""")
	j4 = JSON.parse("""{"a": "aaaaaaaaaaa"}""")
	j5 = JSON.parse("""{"a": "aaaaaaaaaa"}""")
	j6 = JSON.parse("""{"a": "aaaaaaaaa"}""")
	j7 = JSON.parse("""{"a": "$("a"^100)"}""")

	max_string_len = 10
	sha1len = 40
	shorten_suffix = 1 + 3 + 1 + sha1len

	prev_len = JsonGrinder.max_len
	JsonGrinder.updatemaxlen!(max_string_len)
	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7])
	@test sch[:a].counts |> keys .|> length |> maximum <= max_string_len + shorten_suffix
	@test max_string_len + shorten_suffix < 100		# sanity check that we actually shortened it

	JsonGrinder.updatemaxlen!(prev_len)
	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7])
	@test sch[:a].counts |> keys .|> length |> maximum == 100
end

@testset "Schema with string shortening" begin
	j1 = JSON.parse("""{"a": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}""")
	j2 = JSON.parse("""{"a": "b"}""")
	j3 = JSON.parse("""{"a": "🅱️"}""")
	j4 = JSON.parse("""{"a": "aaaaaaaaaaa"}""")
	j5 = JSON.parse("""{"a": "aaaaaaaaaa"}""")
	j6 = JSON.parse("""{"a": "aaaaaaaaa"}""")
	j7 = JSON.parse("""{"a": "$("a"^100)"}""")

	max_string_len = 10
	sha1len = 40
	shorten_suffix = 1 + 3 + 1 + sha1len

	prev_len = JsonGrinder.max_len
	JsonGrinder.updatemaxlen!(max_string_len)
	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7])
	@test sch[:a].counts |> keys .|> length |> maximum <= max_string_len + shorten_suffix
	@test max_string_len + shorten_suffix < 100		# sanity check that we actually shortened it

	JsonGrinder.updatemaxlen!(prev_len)
	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7])
	@test sch[:a].counts |> keys .|> length |> maximum == 100
end

@testset "Schema with fails" begin
	j1 = JSON.parse("""{"a": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}""")
	j2 = Dict("a"=>JsonGrinder)

	sch = JsonGrinder.schema([j1,j2])
	@test sch[:a].updated == 1
end

@testset "Schema with raw jsons" begin
	j1 = """{"a": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"""
	j2 = """{"a": "b"}"""
	j3 = """{"a": "🅱️"}"""
	j4 = """{"a": "aaaaaaaaaaa"}"""
	j5 = """{"a": "aaaaaaaaaa"}"""
	j6 = """{"a": "aaaaaaaaa"}"""
	j7 = """{"a": "$("a"^100)"}"""

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7])
	@test sch[:a].updated == 7
end

@testset "prune_json" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])

	@test JsonGrinder.prune_json(j1, sch) == Dict{String, Any}(
		"c" => Dict("a"=>Dict("b"=>[4.0, 5.0, 6.0],"a"=>[1.0, 2.0, 3.0])),
		"b" => Dict("b"=>1.0,"a"=>[1.0, 2.0, 3.0]),
		"a" => 4.0)

	@test JsonGrinder.prune_json(j2, sch) == Dict{String, Any}(
		"c" => Dict("a"=>Dict("b"=>[5, 6],"a"=>[2, 3])),
		"a" => 4)

	delete!(sch.childs, :b)

	@test JsonGrinder.prune_json(j1, sch) == Dict{String, Any}(
  		"c" => Dict("a"=>Dict("b"=>[4.0, 5.0, 6.0],"a"=>[1.0, 2.0, 3.0])),
  		"a" => 4.0)

	@test JsonGrinder.prune_json(j2, sch) == Dict{String, Any}(
		"c" => Dict("a"=>Dict("b"=>[5, 6],"a"=>[2, 3])),
		"a" => 4)

	delete!(sch.childs, :c)

	@test JsonGrinder.prune_json(j1, sch) == Dict{String, Any}(
  		"a" => 4.0)

	@test JsonGrinder.prune_json(j2, sch) == Dict{String, Any}(
		"a" => 4)

	j1 = JSON.parse("""{"a": 4, "b": {"a":1, "b": 1}}""")
	j2 = JSON.parse("""{"a": 4, "b": {"a":1}}""")
	sch = JsonGrinder.schema([j1,j2])

	j3 = Dict(
		"a" => 4,
		"b" => Dict("a"=>1),
		"c" => 1,
		"d" => 2,
	)

	@test JsonGrinder.prune_json(j1, sch) == j1
	@test JsonGrinder.prune_json(j2, sch) == j2
	@test JsonGrinder.prune_json(j3, sch) == Dict(
		"a"=>4,
		"b"=>Dict(
			"a" => 1
		)
	)
end

num_params(m) = m |> params .|> size .|> prod |> sum
params_empty(m) = m |> params .|> size |> isempty

@testset "suggestextractor with ints and floats numeric and stringy" begin
	j1 = JSON.parse("""{"a": "4"}""")
	j2 = JSON.parse("""{"a": "11.5"}""")
	j3 = JSON.parse("""{"a": 7}""")
	j4 = JSON.parse("""{"a": 4.5}""")

	sch1234 = JsonGrinder.schema([j1,j2,j3,j4])
	sch123 = JsonGrinder.schema([j1,j2,j3])
	sch12 = JsonGrinder.schema([j1,j2])
	sch23 = JsonGrinder.schema([j2,j3])
	sch14 = JsonGrinder.schema([j1,j4])
	sch34 = JsonGrinder.schema([j3,j4])

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
	  └── a: Categorical d = 3 ["U"]
	"""

	@test buf_printtree(ext23, trav=true) ==
  	"""
	Dict [""]
	  └── a: MultiRepresentation ["U"]
	           └── e1: Categorical d = 3 ["k"]
	"""

  	@test buf_printtree(ext34, trav=true) ==
	"""
	Dict [""]
	  └── a: Categorical d = 3 ["U"]
	"""

  	@test buf_printtree(ext14, trav=true) ==
	"""
	Dict [""]
	  └── a: MultiRepresentation ["U"]
	           └── e1: Categorical d = 3 ["k"]
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
	  └── a: Float32 ["U"]
	"""

	@test buf_printtree(ext23, trav=true) ==
  	"""
	Dict [""]
	  └── a: MultiRepresentation ["U"]
	           └── e1: Float32 ["k"]
	"""

  	@test buf_printtree(ext34, trav=true) ==
	"""
	Dict [""]
	  └── a: Float32 ["U"]
	"""

  	@test buf_printtree(ext14, trav=true) ==
	"""
	Dict [""]
	  └── a: MultiRepresentation ["U"]
	           └── e1: Float32 ["k"]
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

@testset "is_numeric is_floatable is_intable" begin
	j1 = JSON.parse("""{"a": "4"}""")
	j2 = JSON.parse("""{"a": "11.5"}""")
	j3 = JSON.parse("""{"a": 7}""")
	j4 = JSON.parse("""{"a": 4.5}""")

	sch1234 = JsonGrinder.schema([j1,j2,j3,j4])
	sch12 = JsonGrinder.schema([j1,j2])
	sch34 = JsonGrinder.schema([j3,j4])
	sch13 = JsonGrinder.schema([j1,j3])
	sch3 = JsonGrinder.schema([j3])
	sch1 = JsonGrinder.schema([j1])
	e = sch1234[:a]

	expected_multientry = JsonGrinder.MultiEntry([
		JsonGrinder.Entry(Dict("4"=>1,"11.5"=>1),2),
		JsonGrinder.Entry(Dict(7=>1,4.5=>1),2)
	], 4)
	@test e == expected_multientry

	e_hash = hash(e)
	@test JsonGrinder.merge_entries_with_cast(e, Int32, Real) == expected_multientry
	# checking that merge_entries_with_cast is not mutating the argument
	@test e_hash == hash(e)

	expected_merged = JsonGrinder.MultiEntry([
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

	expected_merged = JsonGrinder.MultiEntry([
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

	@test JsonGrinder.is_intable(sch1[:a])
	@test JsonGrinder.is_floatable(sch1[:a])
	@test !JsonGrinder.is_numeric_entry(sch1[:a], Real)
end
