@testset "JSON3" begin
    jss = [
        """{"a": 4, "b": {"a": [1, 2, 3], "b": 1},"c": { "a": {"a": [1, 2, 3], "b": [4, 5, 6]}}}""",
        """{"a": 4, "c": { "a": {"a": [2, 3], "b": [5, 6]}}}""",
        """{"a": 4, "b": {"a": [1, 2, 3], "b": 1}}""",
        """{"a": 4, "b": {}}""",
        """{"b": {}}""",
        """{}""",
    ]

    sch1 = JsonGrinder.schema(JSON.parse, jss)
    sch2 = JsonGrinder.schema(JSON3.read, jss)
    @test sch1 == sch2

    e = suggestextractor(sch1)
    for js in jss
        @test isequal(e(JSON.parse(js)), e(JSON3.read(js)))
    end
end
