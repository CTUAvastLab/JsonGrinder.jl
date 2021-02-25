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
		@test e[:e1].data isa MaybeHotMatrix{Union{Missing, Int64},Int64,Union{Missing, Bool}}
		@test nobs(e[:e2]) == 0
		@test e[:e2].data isa NGramMatrix{Union{Missing, String},Union{Missing, Int64}}

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
		@test e[:e2].data.s == ["Olda"]

		e = ex([1,2])
		@test e[:e1].data.data == [1 2]
		@test e[:e2].data.s ≃ [missing]

		
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
		@test e[:e1].data isa MaybeHotMatrix{Int64,Int64,Bool}
		@test nobs(e[:e2]) == 0
		@test e[:e2].data isa NGramMatrix{String,Int64}

		ex2 = MultipleRepresentation((
			ExtractCategorical(["Olda", "Tonda", "Milda"], false),
			JsonGrinder.ExtractString(false)))
		@test hash(ex) === hash(ex2)
		@test ex == ex2

		ex3 = MultipleRepresentation((
			ExtractCategorical(["Polda", "Tonda", "Milada"], false),
			JsonGrinder.ExtractString(false)))
		@test hash(ex) !== hash(ex3)
		@test ex != ex3
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
	  └── e2: String ["U"]"""

	@test buf_printtree(e, trav=true) ==
	"""
	ProductNode with 1 obs [""]
	  ├── e1: ArrayNode(4×1 MaybeHotMatrix with Union{Missing, Bool} elements) with 1 obs ["E"]
	  └── e2: ArrayNode(2053×1 NGramMatrix with Union{Missing, Int64} elements) with 1 obs ["U"]"""

	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"], false),
  		JsonGrinder.ExtractString(false)))
  	e = ex("Olda")

  	@test buf_printtree(ex, trav=true) ==
  	"""
  	MultiRepresentation [""]
  	  ├── e1: Categorical d = 4 ["E"]
  	  └── e2: String ["U"]"""

  	@test buf_printtree(e, trav=true) ==
  	"""
	ProductNode with 1 obs [""]
	  ├── e1: ArrayNode(4×1 MaybeHotMatrix with Bool elements) with 1 obs ["E"]
	  └── e2: ArrayNode(2053×1 NGramMatrix with Int64 elements) with 1 obs ["U"]"""
end
