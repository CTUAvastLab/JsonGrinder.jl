
"""
		newentry(v)

		creates new entry describing json according to the type of v
"""
newentry(v::Dict) = DictEntry()
newentry(v::A) where {A<:StringOrNumber} = Entry()
newentry(v::Vector) = isempty(v) ? ArrayEntry(nothing) : ArrayEntry(newentry(v[1]))

"""
		function schema(a::Vector{T}) where {T<:Dict}
		function schema(a::Vector{T}) where {T<:AbstractString}

		create schema from an array of parsed or unparsed JSONs
"""

function schema(samples::AbstractArray{T}) where {T<:Dict}
	schema = DictEntry()
	failed = Vector{Int}()
	for (i, f) in enumerate(samples)
		try
			update!(schema, f)
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

function schema(samples::AbstractArray{T}) where {T<:AbstractString}
	schema = DictEntry()
	failed = Vector{Int}()
	for (i, f) in enumerate(samples)
		try
			update!(schema, JSON.parse(f))
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
