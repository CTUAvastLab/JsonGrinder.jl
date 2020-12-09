using JsonGrinder, JSON, Test, SparseArrays, Mill
using HierarchicalUtils
import HierarchicalUtils: printtree

@testset "ExtractMultipleRepresentation" begin
	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString()))
	e = ex("Olda")

	@test length(e.data) == 2
	@test size(e.data[1].data) == (4, 1)
	@test e.data[1].data == MaybeHotMatrix([2],4)
	@test size(e.data[2].data) == (2053, 1)
	@test findall(x->x > 0, SparseMatrixCSC(e.data[2].data)) .|> Tuple == [(206, 1), (272, 1), (624, 1), (738, 1), (1536, 1), (1676, 1)]

	e = ex(extractempty)
	@test nobs(e) == 0
	@test nobs(e[:e1]) == 0
	@test e[:e1].data isa MaybeHotMatrix{Int64,Array{Int64,1},Int64,Bool}
	@test nobs(e[:e2]) == 0
	@test e[:e2].data isa NGramMatrix{String,Array{String,1},Int64}

	@test !JsonGrinder.extractsmatrix(ex)

	ex2 = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString()))
	@test hash(ex) === hash(ex2)
	@test ex == ex2

	ex3 = MultipleRepresentation((ExtractCategorical(["Polda", "Tonda", "Milada"]),
		JsonGrinder.ExtractString()))
	@test hash(ex) !== hash(ex3)
	@test ex != ex3
end

@testset "show" begin
	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString()))
	e = ex("Olda")

	@test buf_printtree(ex, trav=true) ==
	"""
	MultiRepresentation [""]
	  ├── e1: Categorical d = 4 ["E"]
	  └── e2: String ["U"]"""

	buf = IOBuffer()
	printtree(buf, e, trav=true)
	str_repr = String(take!(buf))
	@test_broken buf_printtree(e, trav=true) ==
	"""
	ProductNode with 1 obs [""]
	  ├── e1: ArrayNode(4×1 OneHotMatrix, Bool) with 1 obs ["E"]
	  └── e2: ArrayNode(2053×1 NGramMatrix, Int64) with 1 obs ["U"]"""
end
