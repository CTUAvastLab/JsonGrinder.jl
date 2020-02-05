using JsonGrinder, JSON, Test, SparseArrays, Mill

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
end

@testset "show" begin
	ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
		JsonGrinder.ExtractString(String)))
	e = ex("Olda")

	buf = IOBuffer()
	Base.show(buf, ex)
	str_repr = String(take!(buf))
	@test str_repr ==
"""
: MultiRepresentation
  ├─── : Categorical d = 4
  └─── : String
"""

	buf = IOBuffer()
	Mill.dsprint(buf, e)
	str_repr = String(take!(buf))
	@test str_repr ==
"""
TreeNode
  ├── ArrayNode(4, 1)
  └── ArrayNode(2053, 1)"""
end
