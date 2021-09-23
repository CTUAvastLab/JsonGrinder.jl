const _max_keys = Ref(10_000)

"""
	updatemaxkeys!(n::Int)

	limits the maximum number of keys in statistics of nodes in JSON. Default value is 10_000.
"""
updatemaxkeys!(n::Int) = _max_keys[] = n
max_keys() = _max_keys[]

const _max_len = Ref(10_000)

"""
	updatemaxlen!(n::Int)

	limits the maximum size of string values in statistics of nodes in JSON. Default value is 10_000.
	Longer strings will be trimmed and their length and hash will be appended to retain the uniqueness.
	This is due to some strings being very long and causing the schema to be even order of magnitute larger than needed.
"""
updatemaxlen!(n::Int) = _max_len[] = n
max_len() = _max_len[]

_skip_single_key_dict = Ref(true)
"""
	skip_single_key_dict!(v::Bool)

	Skips single keys in extraction of dict. If on, it's a performance optimization because it ommits intermediate layer which semantically does not make much sense, 
	but it breaks consistency between schema, extractor and sample. If turned off, it keeps sample as is, thus resuling in larger network.
"""
skip_single_key_dict!(v::Bool) = _skip_single_key_dict[] = v
skip_single_key_dict() = _skip_single_key_dict[]

_add_metadata2dicts = Ref(true)

add_metadata2dicts!(n::Bool) = _add_metadata2dicts[] = n
add_metadata2dicts() = _add_metadata2dicts[]

_merge_scalars = Ref(true)

"""
	merge_scalars!(n::Bool)

	Allows merging of scalars, which leads to more efficient implementation, becase scalars don't have their own layers, but share one. 
	It breaks consistency between schema, extractor and sample. If turned off, it keeps sample as is, thus resuling in larger network.
"""
merge_scalars!(n::Bool) = _merge_scalars[] = n
merge_scalars() = _merge_scalars[]
