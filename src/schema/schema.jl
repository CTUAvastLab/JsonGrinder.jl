using JSON, Printf
import Base: merge, length

abstract type AbstractExtractor end
abstract type JSONEntry end
StringOrNumber = Union{AbstractString,Number}
max_keys = 10_000

"""
	updatemaxkeys!(n::Int)

limits the maximum number of keys in statistics of leaves in JSON. Default value is `10_000`.
"""
function updatemaxkeys!(n::Int)
	global max_keys = n
end

max_len = 10_000

"""
	updatemaxlen!(n::Int)

limits the maximum length of string values in statistics of nodes in JSON. Default value is `10_000`.
Longer strings will be trimmed and their length and hash will be appended to retain the uniqueness.
This is due to some strings being very long and causing the schema to be even order of magnitute larger than needed.
"""
function updatemaxlen!(n::Int)
	global max_len = n
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

function Mill.reflectinmodel(sch::JSONEntry, ex::AbstractExtractor, fm=d->Flux.Dense(d, 10), fa=d->SegmentedMean(d); fsm = Dict(), fsa = Dict(),
			   single_key_identity=true, single_scalar_identity=true)
	# we do catobs of 3 samples here, because we want full representative sample to build whole "supersample" from which some samples are just subset
	# we also want sample with leaves missing in places where leaves can be actually missing in order to have imputation in all correct places
	# and missing sample is to cover other various edgecases
	full_sample = ex(sample_synthetic(sch, empty_dict_vals=false))
	leaves_empty_sample = ex(sample_synthetic(sch, empty_dict_vals=true))
	missing_sample = ex(missing)
	specimen = catobs(full_sample, leaves_empty_sample, missing_sample)
	# reflectinmodel(specimen, fm, fa, b=fsm, a=fsa, single_key_identity=single_key_identity, single_scalar_identity=single_scalar_identity)
	# uncomment this is you want to use the #master version
	reflectinmodel(specimen, fm, fa, fsm=fsm, fsa=fsa, single_key_identity=single_key_identity, single_scalar_identity=single_scalar_identity)
end


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


"""
	prune_json(json, schema)

Removes keys from `json` which are not part of the `schema`.

# Example
```jldoctest
julia> j1 = JSON.parse("{\"a\": 4, \"b\": {\"a\":1, \"b\": 1}}");

julia> j2 = JSON.parse("{\"a\": 4, \"b\": {\"a\":1}}");

julia> sch = JsonGrinder.schema([j1,j2])
[Dict] (updated = 2)
  ├── a: [Scalar - Int64], 1 unique values, updated = 2
  └── b: [Dict] (updated = 2)
           ├── a: [Scalar - Int64], 1 unique values, updated = 2
           └── b: [Scalar - Int64], 1 unique values, updated = 1
julia> j3 = Dict("a" => 4, "b" => Dict("a"=>1), "c" => 1, "d" => 2)
Dict{String,Any} with 4 entries:
  "c" => 1
  "b" => Dict("a"=>1)
  "a" => 4
  "d" => 2
julia> JsonGrinder.prune_json(j3, sch)
Dict{Any,Any} with 2 entries:
    "b" => Dict{Any,Any}("a"=>1)
    "a" => 4
```
so the `JsonGrinder.prune_json` removes keys `c` and `d`.
"""
prune_json(json, sch::Entry) = json

prune_json(json, sch::ArrayEntry) = map(json) do el
	prune_json(el, sch.items)
end

function prune_json(json, sch::DictEntry)
    out = Dict()
    for (k,v) in children(sch)
        String(k) ∈ keys(json) && (out[String(k)] = prune_json(json[String(k)], v))
    end
    out
end
