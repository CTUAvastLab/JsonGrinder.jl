using JsonGrinder, JSON, Test

@testset "ExtractOneHot" begin 
	samples = ["{\"name\": \"a\", \"count\" : 1}",
		"{\"name\": \"b\", \"count\" : 2}",]
	vs = JSON.parse.(samples)

	e = ExtractOneHot(["a","b"], "name", "count")
	@test e(vs).data[:] ≈ [1, 2, 0]

	e = ExtractOneHot(["a","b"], "name", nothing)
	@test e(vs).data[:] ≈ [1, 1, 0]
	vs = JSON.parse.(["{\"name\": \"c\", \"count\" : 1}"])
	@test e(vs).data[:] ≈ [0, 0, 1]
end
