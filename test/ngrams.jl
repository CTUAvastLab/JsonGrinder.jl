using Base.Test
using Revise
using JsonGrinder
x = [1,3,5,2,6,8,3]
b = 8 + 1
n = 3

slicer = (x,n) -> map(i -> x[(max(i-n+1,1):min(i,length(x)))],1:length(x)+n-1)
indexes = (x,b) -> mapreduce(i -> i[2]*b^(i[1]-1), +, enumerate(reverse(x)))

@testset "testing ngrams on vector of ints" begin 
		@test all(JsonGrinder.ngrams(x,n,b) .== map(x -> indexes(x,b),slicer(x,n)))
end