class_name DictIO
extends RefCounted
## Typed readers for from_dict(). JSON parsing yields floats for every number, so readers convert
## integral floats to int explicitly. Missing keys fall back to the given default.


static func int_of(d: Dictionary, key: String, default: int = 0) -> int:
	if not d.has(key) or d[key] == null:
		return default
	var v: Variant = d[key]
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_BOOL:
		return 1 if v else 0
	return default


static func str_of(d: Dictionary, key: String, default: String = "") -> String:
	if not d.has(key) or d[key] == null:
		return default
	return str(d[key])


static func bool_of(d: Dictionary, key: String, default: bool = false) -> bool:
	if not d.has(key) or d[key] == null:
		return default
	return bool(d[key])


static func dict_of(d: Dictionary, key: String) -> Dictionary:
	if d.has(key) and typeof(d[key]) == TYPE_DICTIONARY:
		return d[key]
	return {}


static func arr_of(d: Dictionary, key: String) -> Array:
	if d.has(key) and typeof(d[key]) == TYPE_ARRAY:
		return d[key]
	return []


static func str_arr(d: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in arr_of(d, key):
		out.append(str(v))
	return out


static func int_arr(d: Dictionary, key: String) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in arr_of(d, key):
		out.append(int(v))
	return out


## String -> int map (stocks, flags, counters).
static func int_map(d: Dictionary, key: String) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	var src: Dictionary = dict_of(d, key)
	for k: Variant in src.keys():
		out[str(k)] = int(src[k])
	return out


## String -> String map.
static func str_map(d: Dictionary, key: String) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var src: Dictionary = dict_of(d, key)
	for k: Variant in src.keys():
		out[str(k)] = str(src[k])
	return out


## Sorted keys of any dictionary with String keys. Simulation code iterates collections through
## this so a loaded game and a live game visit entities in the same order.
static func sorted_keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in d.keys():
		out.append(str(k))
	out.sort()
	return out


## Converts a typed or untyped String->int map to a plain Dictionary for to_dict().
static func plain(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d.keys():
		out[k] = d[k]
	return out
