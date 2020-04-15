
"""
		function Schema(a::Vector{T}) where {T<:Dict}
		function schema(a::Vector{T}) where {T<:AbstractString}

		create schema from an array of parsed or unparsed JSONs
"""

function Schema(iterator::Base.Iterators.Enumerate)
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

Schema(samples::AbstractArray{T}) where {T<:Dict} = Schema(enumerate(samples))


function Schema(file::String) where {T<:AbstractString}
	schema = DictEntry()
	failed = Vector{Int}()
	for (i, f) in enumerate(readlines(file))
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
