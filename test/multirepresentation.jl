using JsonGrinder, JSON, Test, SparseArrays, Mill, HierarchicalUtils
import HierarchicalUtils: printtree
using Mill: nobs

@testset "ExtractMultipleRepresentation" begin
	@testset "with uniontypes" begin
		ex = MultipleRepresentation((
			ExtractCategorical(["Olda", "Tonda", "Milda"], true),
			ExtractString(true)))
		e = ex("Olda")

		@test nobs(e) == 1
		@test length(e.data) == 2
		@test size(e.data[1].data) == (4, 1)
		@test e.data[1].data == MaybeHotMatrix([2],4)
		@test size(e.data[2].data) == (2053, 1)
		@test findall(x->x > 0, SparseMatrixCSC(e.data[2].data)) .|> Tuple == [(206, 1), (272, 1), (624, 1), (738, 1), (1536, 1), (1676, 1)]

		e = ex(extractempty)
		@test nobs(e) == 0
		@test nobs(e[:e1]) == 0
		@test e[:e1].data isa MaybeHotMatrix{Union{Missing, UInt32}, UInt32, Union{Missing, Bool}}
		@test nobs(e[:e2]) == 0
		@test e[:e2].data isa NGramMatrix{Union{Missing, String},Vector{Union{Missing, String}},Union{Missing, Int64}}

		ex2 = MultipleRepresentation((
			ExtractCategorical(["Olda", "Tonda", "Milda"], true),
			JsonGrinder.ExtractString(true)))
		@test hash(ex) === hash(ex2)
		@test ex == ex2

		ex3 = MultipleRepresentation((
			ExtractCategorical(["Polda", "Tonda", "Milada"], true),
			ExtractString(true)))
		@test hash(ex) !== hash(ex3)
		@test ex != ex3

		ex = MultipleRepresentation((
			ExtractArray(JsonGrinder.extractscalar(Float32, true)),
			ExtractString(true)))
		e = ex("Olda")
		@test e[:e1].data.data == fill(1,1,0)
		@test e[:e2].data.S == ["Olda"]

		e = ex([1,2])
		@test e[:e1].data.data == [1 2]
		@test e[:e2].data.S ≃ [missing]

		ex = MultipleRepresentation([
        	ExtractCategorical(["packer", "plain"], true),
        	ExtractArray(ExtractString(true))
        ])

		@test ex(["sfx", "plain"]) ≃ ProductNode((;
			:e1=>ArrayNode(MaybeHotMatrix([missing], 3)),
			:e2=>BagNode(
				ArrayNode(NGramMatrix(["sfx", "plain"])),
				[1,1])
		))

		@test ex(["sfx", "plain"]) ≃ ex(Any["sfx", "plain"])
		@test ex(["sfx", "plain"]) ≃ ex(String["sfx", "plain"])
	end

	@testset "without uniontypes" begin
		ex = MultipleRepresentation((
			ExtractCategorical(["Olda", "Tonda", "Milda"], false),
			ExtractString(false)))
		e = ex("Olda")

		@test length(e.data) == 2
		@test size(e.data[1].data) == (4, 1)
		@test e.data[1].data == MaybeHotMatrix([2],4)
		@test size(e.data[2].data) == (2053, 1)
		@test findall(x->x > 0, SparseMatrixCSC(e.data[2].data)) .|> Tuple == [(206, 1), (272, 1), (624, 1), (738, 1), (1536, 1), (1676, 1)]

		e = ex(extractempty)
		@test nobs(e) == 0
		@test nobs(e[:e1]) == 0
		@test e[:e1].data isa OneHotMatrix{UInt32, UInt32(4), Vector{UInt32}}
		@test nobs(e[:e2]) == 0
		@test e[:e2].data isa NGramMatrix{String,Array{String,1},Int64}

		ex2 = MultipleRepresentation((
			ExtractCategorical(["Olda", "Tonda", "Milda"], false),
			ExtractString(false)))
		@test hash(ex) === hash(ex2)
		@test ex == ex2

		ex3 = MultipleRepresentation((
			ExtractCategorical(["Polda", "Tonda", "Milada"], false),
			ExtractString(false)))
		@test hash(ex) !== hash(ex3)
		@test ex != ex3

		ex = MultipleRepresentation([
        	ExtractCategorical(["packer", "plain"], false),
        	ExtractArray(ExtractString(false))
        ])
		@test_throws ErrorException ex(["sfx", "plain"])
	end
end

@testset "show" begin
	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"], true),
		JsonGrinder.ExtractString(true)))
	e = ex("Olda")

	@test buf_printtree(ex, trav=true) ==
	"""
	MultiRepresentation [""]
	  ├── e1: Categorical d = 4 ["E"]
	  └── e2: String ["U"]
	"""

	@test buf_printtree(e, trav=true) ==
	"""
	ProductNode [""] \t# 1 obs, 48 bytes
	  ├── e1: ArrayNode(4×1 MaybeHotMatrix with Union{Missing, Bool} elements) ["E"] \t# 1 obs, 77 bytes
	  └── e2: ArrayNode(2053×1 NGramMatrix with Union{Missing, Int64} elements) ["U"] \t# 1 obs, 124 bytes
	"""

	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"], false),
  		JsonGrinder.ExtractString(false)))
  	e = ex("Olda")

  	@test buf_printtree(ex, trav=true) ==
	"""
	MultiRepresentation [""]
	  ├── e1: Categorical d = 4 ["E"]
	  └── e2: String ["U"]
	"""

	@test buf_printtree(e, trav=true) ==
	"""
	ProductNode [""] \t# 1 obs, 40 bytes
	  ├── e1: ArrayNode(4×1 OneHotArray with Bool elements) ["E"] \t# 1 obs, 60 bytes
	  └── e2: ArrayNode(2053×1 NGramMatrix with Int64 elements) ["U"] \t# 1 obs, 124 bytes
	"""
end
