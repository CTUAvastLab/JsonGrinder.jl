using JsonGrinder, JSON, Test, SparseArrays, Mill, HierarchicalUtils
import HierarchicalUtils: printtree
using Mill: nobs

@testset "ExtractMultipleRepresentation" begin
	ex = MultipleRepresentation((
		ExtractCategorical(["Olda", "Tonda", "Milda"]),
		ExtractString(String)))
	e = ex("Olda")

    @test nobs(e) == 1
	@test length(e.data) == 2
	@test size(e.data[1].data) == (4, 1)
	@test e.data[1].data[:] ≈ [0, 1, 0, 0]
	@test size(e.data[2].data) == (2053, 1)
	@test findall(x->x > 0, SparseMatrixCSC(e.data[2].data)) .|> Tuple == [(80, 1), (98, 1), (206, 1), (738, 1),
		(1062, 1), (1856, 1)]

	@test !JsonGrinder.extractsmatrix(ex)

	ex2 = MultipleRepresentation((
	    ExtractCategorical(["Olda", "Tonda", "Milda"]),
		ExtractString(String)))
	@test hash(ex) === hash(ex2)
	@test ex == ex2

	ex3 = MultipleRepresentation((
	    ExtractCategorical(["Polda", "Tonda", "Milada"]),
		ExtractString(String)))
	@test hash(ex) !== hash(ex3)
	@test ex != ex3
end

@testset "show" begin
	ex = MultipleRepresentation((
		ExtractCategorical(["Olda", "Tonda", "Milda"]),
		ExtractString(String)))
	e = ex("Olda")

	@test buf_printtree(ex, trav=true) ==
	"""
	MultiRepresentation [""]
	  ├── e1: Categorical d = 4 ["E"]
	  └── e2: String ["U"]"""

	@test buf_printtree(e, trav=true) ==
	"""
	ProductNode [""]
	  ├── e1: ArrayNode(4, 1) ["E"]
	  └── e2: ArrayNode(2053, 1) ["U"]"""
end
