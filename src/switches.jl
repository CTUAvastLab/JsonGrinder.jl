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
