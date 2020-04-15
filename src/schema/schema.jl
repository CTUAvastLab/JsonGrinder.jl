using JSON, Printf
import Base: merge, length

abstract type AbstractExtractor end
abstract type JSONEntry end
StringOrNumber = Union{String,Number}
max_keys = 10000

"""
	updatemaxkeys!(n::Int)

	limits the maximum number of keys in statistics of nodes in JSON. Default value is 10000. 
"""
function updatemaxkeys!(n::Int)
	global max_keys = n
end

include("scalar.jl")
include("dict.jl")
include("array.jl")
include("makeschema.jl")

updated(s::T) where {T<:JSONEntry} = s.updated
merge(combine::typeof(merge), es::JSONEntry...) = merge(es...)
merge(::Nothing, e::JSONEntry) = e

Mill.reflectinmodel(sch::JSONEntry, ex::AbstractExtractor, db, da=d->SegmentedMean(d); b = Dict(), a = Dict()) =
	reflectinmodel(ex(sample_synthetic(sch)), db, da, b=b, a=a)

function make_selector(s::Symbol)
	if s == Symbol("[]")
		return (d) -> d.items
	else
		return (d) -> d.childs[s]
	end
end

"""
		Deletes `field` at the specified `path` from the schema `sch`.
		For instance, the following:
			`delete!(schema, ".field.subfield.[]", "x")``
		deletes the field `x` from `schema` at:
			`schema.childs[:field].childs[:subfield].items.childs`
"""
function Base.delete!(sch::JSONEntry, path::AbstractString, field::AbstractString)
	@assert field != "[]"

	selectors = map(Symbol, split(path, ".")[2:end])

	item = reduce((s, f) -> f(s), map(make_selector, selectors), init=sch)

	delete!(item.childs, Symbol(field))
end
