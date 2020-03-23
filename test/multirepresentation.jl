using JsonGrinder, JSON, Test, SparseArrays, Mill
using HierarchicalUtils
import HierarchicalUtils: printtree

@testset "ExtractMultipleRepresentation" begin
	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString(String)))
	e = ex("Olda")

	@test length(e.data) == 2
	@test size(e.data[1].data) == (4, 1)
	@test e.data[1].data[:] ≈ [0, 1, 0, 0]
	@test size(e.data[2].data) == (2053, 1)
	@test findall(x->x > 0, SparseMatrixCSC(e.data[2].data)) .|> Tuple == [(80, 1), (98, 1), (206, 1), (738, 1),
		(1062, 1), (1856, 1)]

	@test !JsonGrinder.extractsmatrix(ex)

	ex2 = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString(String)))
	@test hash(ex) === hash(ex2)
	@test ex == ex2

	ex3 = MultipleRepresentation((ExtractCategorical(["Polda", "Tonda", "Milada"]),
		JsonGrinder.ExtractString(String)))
	@test hash(ex) !== hash(ex2)
	@test ex != ex2
end

@testset "show" begin
	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString(String)))
	e = ex("Olda")

	buf = IOBuffer()
	printtree(buf, ex, trav=true)
	str_repr = String(take!(buf))
	@test str_repr ==
"""
MultiRepresentation [""]
  ├── Categorical d = 4 ["E"]
  └── String ["U"]"""

	buf = IOBuffer()
	printtree(buf, e, trav=true)
	str_repr = String(take!(buf))
	@test str_repr ==
"""
ProductNode [""]
  ├── ArrayNode(4, 1) ["E"]
  └── ArrayNode(2053, 1) ["U"]"""
end
