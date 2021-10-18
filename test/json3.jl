using JSON, JSON3, Test, JsonGrinder

@testset "JSON and JSON3 parity" begin
    j1 = """{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}"""
	j2 = """{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}"""
	j3 = """{"a": 4, "b": {"a":[1,2,3],"b": 1}}"""
	j4 = """{"a": 4, "b": {}}"""
	j5 = """{"b": {}}"""
	j6 = """{}"""

	sch1 = JsonGrinder.schema([j1,j2,j3,j4,j5,j6], JSON.parse)
	sch2 = JsonGrinder.schema([j1,j2,j3,j4,j5,j6], JSON3.read)
    @test sch1 == sch2
end
