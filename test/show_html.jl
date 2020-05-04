using JsonGrinder, JSON, Test, SparseArrays

@testset "Generating HTML Schema" begin
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

	JsonGrinder.updatemaxkeys!(6)

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8,j9,j10,j11])

	JsonGrinder.generate_html(sch, "schema_test_maxvals=5.html", max_vals=5)
	@test isfile("schema_test_maxvals=5.html")
end

@testset "Generating HTML Schema" begin
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

	JsonGrinder.generate_html(sch, "schema_test_maxvals=5.html", max_vals=5)
	@test isfile("schema_test_maxvals=5.html")
end
