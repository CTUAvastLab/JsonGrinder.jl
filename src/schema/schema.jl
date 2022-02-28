using JSON, Printf
import Base: merge, length

abstract type AbstractExtractor end
abstract type BagExtractor <: AbstractExtractor end
abstract type JSONEntry end
StringOrNumber = Union{AbstractString,Number}

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

# todo: test if schema for ints and floats if different oderings behaves the same
# todo: test if schema where samples are string and abstractstring is working properly
#   maybe treat all strings as abstractstrings?
# todo: test if I have string and dict in same key in json, and that schema building behaves the same not matter that order are they in
#     (it should not matter if it first sees dict or string)

updated(s::T) where {T<:JSONEntry} = s.updated
merge(combine::typeof(merge), es::JSONEntry...) = merge(es...)
merge(::Nothing, e::JSONEntry) = e

make_representative_sample(sch::JSONEntry, ex::AbstractExtractor) = ex(sample_synthetic(sch))

function Mill.reflectinmodel(sch::JSONEntry, ex::AbstractExtractor, args...; kwargs...)
	# because we have type-stable extractors, we now have information about what is missing and what not inside types
	# so I don't have to extract empty and missing samples, the logic is now part of suggestextractor
	specimen = make_representative_sample(sch, ex)
	reflectinmodel(specimen, args...; kwargs...)
end

# this can probably be
make_selector(s) = e->select_by_string(s, e)
select_by_string(s::AbstractString, e::DictEntry) = e.childs[Symbol(s)]
select_by_string(s::AbstractString, e::ArrayEntry) = s == "[]" ? e.items : @error "wrong selector"
select_by_string(s::AbstractString, e::MultiEntry) = e.childs[parse(Int, s)]

"""
Deletes `field` at the specified `path` from the schema `sch`.
For instance, the following:
	`delete!(schema, ".field.subfield.[]", "x")`
deletes the field `x` from `schema` at:
	`schema.childs[:field].childs[:subfield].items.childs`
"""
function Base.delete!(sch::JSONEntry, path::AbstractString, field::AbstractString)
	@assert field != "[]"
	selectors = split(path, ".")[2:end]
	item = reduce((s, f) -> f(s), make_selector.(selectors), init=sch)
	delete!(item.childs, Symbol(field))
end


"""
	prune_json(json, schema)

Removes keys from `json` which are not part of the `schema`.

# Example
```jldoctest
julia> using JSON

julia> j1 = JSON.parse("{\\"a\\": 4, \\"b\\": {\\"a\\":1, \\"b\\": 1}}");

julia> j2 = JSON.parse("{\\"a\\": 4, \\"b\\": {\\"a\\":1}}");

julia> sch = JsonGrinder.schema([j1,j2])
[Dict] \t# updated = 2
  ├── a: [Scalar - Int64], 1 unique values \t# updated = 2
  └── b: [Dict] \t# updated = 2
           ├── a: [Scalar - Int64], 1 unique values \t# updated = 2
           └── b: [Scalar - Int64], 1 unique values \t# updated = 1

julia> j3 = Dict("a" => 4, "b" => Dict("a"=>1), "c" => 1, "d" => 2)
Dict{String, Any} with 4 entries:
  "c" => 1
  "b" => Dict("a"=>1)
  "a" => 4
  "d" => 2

julia> JsonGrinder.prune_json(j3, sch)
Dict{String, Any} with 2 entries:
  "b" => Dict("a"=>1)
  "a" => 4
```
so the `JsonGrinder.prune_json` removes keys `c` and `d`.
"""
prune_json(json, sch::Entry) = json

prune_json(json, sch::ArrayEntry) = map(json) do el
	prune_json(el, sch.items)
end

prune_json(json, sch::DictEntry) =
    Dict(String(k) => prune_json(json[String(k)], v) for (k,v) in children(sch) if String(k) ∈ keys(json))
