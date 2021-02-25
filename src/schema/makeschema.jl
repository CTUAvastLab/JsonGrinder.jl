using BSON: BSONDict
"""
	newentry(v)

creates new entry describing json according to the type of v
"""
newentry(v::Dict) = DictEntry()
newentry(v::BSONDict) = newentry(v.d)
newentry(v::A) where {A<:StringOrNumber} = Entry(v)
newentry(v::Vector) = isempty(v) ? ArrayEntry(nothing) : ArrayEntry(newentry(v[1]))
function newentry!(v)
	c = newentry(v)
	update!(c, v)
	c
end

"""
	schema(samples::AbstractArray{<:Dict})
	schema(samples::AbstractArray{<:AbstractString})
	schema(samples::AbstractArray, map_fun::Function)
	schema(map_fun::Function, samples::AbstractArray)

creates schema from an array of parsed or unparsed JSONs.
"""
function schema(samples::AbstractArray, map_fun::Function)
	schema = DictEntry()
	failed = Vector{Int}()
	for (i, f) in enumerate(samples)
		try
			update!(schema, map_fun(f))
		catch
			push!(failed, i)
		end
	end
	if !isempty(failed)
		println("failed on $(length(failed)) samples")
		l = min(10, length(failed))
		println("for example on samples with indexes$(failed[1:l])")
	end
	schema
end

schema(map_fun::Function, samples::AbstractArray) = schema(samples, map_fun)
schema(samples::AbstractArray{<:Dict}) = schema(samples, identity)
schema(samples::AbstractArray{<:AbstractString}) = schema(samples, JSON.parse)
# BSON integration
schema(samples::AbstractArray{<:BSONDict}) = schema(samples, identity)
