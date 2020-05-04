using JSON, Printf
import Base: merge, length

abstract type AbstractExtractor end
abstract type JSONEntry end
StringOrNumber = Union{AbstractString,Number}
max_keys = 10000

"""
	updatemaxkeys!(n::Int)

	limits the maximum number of keys in statistics of nodes in JSON. Default value is 10000.
"""
function updatemaxkeys!(n::Int)
	global max_keys = n
end

function safe_update!(s::JSONEntry, d; path = "")
	success = update!(s, d)
	isnothing(success) && return nothing
	success && return s
	@info "In path $path: Instability in the schema detected. Using multiple representation."
	s = MultiEntry([s], s.updated)
	update!(s, d, path=path)
	return s
end
safe_update!(::Nothing, d; path = "") = newentry!(d)
update!(s::JSONEntry, d; path = "") = false

include("scalar.jl")
include("dict.jl")
include("array.jl")
include("multientry.jl")
include("makeschema.jl")

# todo: otestovat si schema pro inty a floaty v různém pořadí
# todo : pro multirepresentation mít inty a stringy
# todo: pro stringy to natvrdo přetypovat na abstractstringy, aby to pobralo šimonovu issue
# todo: otestovat když mám na stejném fieldu stringy a dictionary, co se stane když bude první dict nebo string, otestovat a popsat

updated(s::T) where {T<:JSONEntry} = s.updated
merge(combine::typeof(merge), es::JSONEntry...) = merge(es...)
merge(::Nothing, e::JSONEntry) = e

Mill.reflectinmodel(sch::JSONEntry, ex::AbstractExtractor, db, da=d->SegmentedMean(d); b = Dict(), a = Dict()) =
	reflectinmodel(ex(sample_synthetic(sch)), db, da, b=b, a=a)

make_selector(s::Symbol) = s == Symbol("[]") ? d->d.items : d-> d.childs[s]

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
