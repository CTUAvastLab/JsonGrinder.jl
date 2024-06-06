@testset "PolymorphExtractor io" begin
    e = PolymorphExtractor((
        CategoricalExtractor(["foo", "bar", "baz"]),
        JsonGrinder.NGramExtractor()
    ))

    @test repr(e) == repr(e; context=:compact => true) == "PolymorphExtractor"
    @test repr(MIME("text/plain"), e) ==
        """
        PolymorphExtractor
          ├── CategoricalExtractor(n=4)
          ╰── NGramExtractor(n=3, b=256, m=2053)"""
end
