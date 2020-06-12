using JsonGrinder, JSON, Test, SparseArrays

@testset "Strigifying" begin
	@test JsonGrinder.stringify(1, 2) == "1: 2"
	@test JsonGrinder.stringify("<b>a</b>", 2) == "&lt;b&gt;a&lt;/b&gt;: 2"
	@test length("a<bcd" ^ 1_000) == 5_000
	@test JsonGrinder.stringify("a<bcd" ^ 1_000, 3, max_len=20) == "a&lt;bcda&lt;bcda&lt;bcda&lt;bcd: 3"
end

@testset "Entry creation" begin
	e = JsonGrinder.newentry("a")
	JsonGrinder.update!(e, "a")
	JsonGrinder.update!(e, "a")
	JsonGrinder.update!(e, "<b")
	JsonGrinder.update!(e, "c")
	JsonGrinder.update!(e, "d")
	JsonGrinder.update!(e, "d")
	JsonGrinder.update!(e, "d")
	JsonGrinder.update!(e, "e" ^ 1_000)
	html = JsonGrinder.schema2html(e, max_len=10)
	html2 = """<ul class="nested" style="color: #4E79A7">[Scalar - String], 5 unique values,
	(updated = 8, min=eeeeeeeeee: 1, max=d: 3)
	  <li>d: 3</li>
	  <li>a: 2</li>
	  <li>&lt;b: 1</li>
	  <li>c: 1</li>
	  <li>eeeeeeeeee: 1</li>
	 </ul>
	"""
	@test html == html2
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
	j9 = JSON.parse("""{"a": [{"a":4,"b":3},{"b":2,"a":2}], "b":2}""")
	j10 = JSON.parse("""{"a": [{"a":11,"b":12},{"b":13,"a":14}], "b":2}""")
	j11 = JSON.parse("""{"a": [{"a":7,"b":5},{"b":6,"a":6}], "b":2}""")

	JsonGrinder.updatemaxkeys!(6)

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8,j9,j10,j11])

	JsonGrinder.generate_html(sch, "schema_test_maxvals=5.html", max_vals=5)
	@test isfile("schema_test_maxvals=5.html")
end

@testset "Generating Irregular HTML schema" begin
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
