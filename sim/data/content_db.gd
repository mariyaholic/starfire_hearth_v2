class_name ContentDb
extends RefCounted
## Loads data/*.json into id-keyed tables. Numbers become ints, and authoring strings such as
## "4.00" in centi fields become centi-units, once, at load. Problems are collected in `errors`;
## DataValidator reports them together with its own checks.

const DEFAULT_ROOT: String = "res://data"

var root: String = DEFAULT_ROOT
## Table name -> {id -> record}.
var tables: Dictionary[String, Dictionary] = {}
## Table name -> ids in file order.
var order: Dictionary[String, Array] = {}
## File name -> top-level "version".
var versions: Dictionary[String, int] = {}
## Scenario id -> scenario document.
var scenarios: Dictionary[String, Dictionary] = {}
## File name (in data/scenarios) -> scenario id, to check that they agree.
var scenario_files: Dictionary[String, String] = {}
## Event chain id -> chain document (data/events/*.json).
var events: Dictionary[String, Dictionary] = {}
## Codex entry id -> authored markdown (data/codex/*.md).
var codex: Dictionary[String, String] = {}
var errors: Array[String] = []


static func load_from(p_root: String = DEFAULT_ROOT) -> ContentDb:
	var db: ContentDb = ContentDb.new()
	db.root = p_root
	for tname: String in DataSchema.TABLES.keys():
		db._load_table(tname, DataSchema.TABLES[tname])
	db._load_dir_json("scenarios", db.scenarios, db.scenario_files)
	var event_files: Dictionary[String, String] = {}
	db._load_dir_json("events", db.events, event_files)
	db._load_codex()
	return db


func table(name: String) -> Dictionary:
	return tables.get(name, {})


func has(table_name: String, id: String) -> bool:
	return table(table_name).has(id)


func record(table_name: String, id: String) -> Dictionary:
	return table(table_name).get(id, {})


func ids(table_name: String) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in order.get(table_name, []):
		out.append(str(v))
	return out


func _load_table(tname: String, spec: Dictionary) -> void:
	var fname: String = spec["file"]
	var doc: Variant = _read_json(root.path_join(fname))
	tables[tname] = {}
	order[tname] = []
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var d: Dictionary = doc
	versions[fname] = DictIO.int_of(d, "version", -1)
	var list_key: String = spec["list"]
	if not d.has(list_key) or typeof(d[list_key]) != TYPE_ARRAY:
		errors.append("%s: missing top-level list \"%s\"" % [fname, list_key])
		return
	for extra: Variant in d.keys():
		if extra != "version" and extra != list_key:
			errors.append("%s: unknown top-level key \"%s\"" % [fname, str(extra)])
	var fields: Dictionary = spec["fields"]
	var i: int = 0
	for rec: Variant in d[list_key]:
		if typeof(rec) != TYPE_DICTIONARY:
			errors.append("%s: entry %d is not an object" % [fname, i])
			i += 1
			continue
		var r: Dictionary = _convert_record(rec, fields, "%s[%d]" % [fname, i])
		var id: String = DictIO.str_of(r, "id")
		if id.is_empty():
			errors.append("%s: entry %d has no id" % [fname, i])
		elif tables[tname].has(id):
			errors.append("%s: duplicate id \"%s\"" % [fname, id])
		else:
			tables[tname][id] = r
			order[tname].append(id)
		i += 1


## Converts centi-typed fields from authoring strings; everything else passes through.
func _convert_record(rec: Dictionary, fields: Dictionary, where: String) -> Dictionary:
	var out: Dictionary = rec.duplicate(true)
	for fname: Variant in fields.keys():
		if not out.has(fname):
			continue
		var ftype: String = str(fields[fname]).trim_prefix("?")
		out[fname] = _convert_value(out[fname], ftype, "%s.%s" % [where, str(fname)])
	return out


func _convert_value(v: Variant, ftype: String, where: String) -> Variant:
	if ftype == "centi" and typeof(v) == TYPE_STRING:
		var parsed: Array = Fx.parse_centi(v)
		if parsed[0]:
			return parsed[1]
		errors.append("%s: \"%s\" is not an amount like \"4.00\"" % [where, v])
		return v
	if ftype == "res_map" and typeof(v) == TYPE_DICTIONARY:
		var m: Dictionary = v
		var conv: Dictionary = {}
		for k: Variant in m.keys():
			conv[k] = _convert_value(m[k], "centi", "%s.%s" % [where, str(k)])
		return conv
	if ftype.begins_with("list:") and typeof(v) == TYPE_ARRAY:
		var inner: String = ftype.trim_prefix("list:")
		var arr: Array = v
		var conv_a: Array = []
		for j in arr.size():
			conv_a.append(_convert_value(arr[j], inner, "%s[%d]" % [where, j]))
		return conv_a
	if ftype.begins_with("obj:") and typeof(v) == TYPE_DICTIONARY:
		var sub: Dictionary = DataSchema.OBJECTS.get(ftype.trim_prefix("obj:"), {})
		return _convert_record(v, sub, where)
	return v


func _load_dir_json(sub: String, into: Dictionary, files: Dictionary) -> void:
	var dir_path: String = root.path_join(sub)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		errors.append("missing folder data/%s" % sub)
		return
	var names: Array[String] = []
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f: String in names:
		var doc: Variant = _read_json(dir_path.path_join(f))
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = doc
		var id: String = DictIO.str_of(d, "id")
		if id.is_empty():
			errors.append("data/%s/%s: missing id" % [sub, f])
			continue
		if into.has(id):
			errors.append("data/%s/%s: duplicate id \"%s\"" % [sub, f, id])
			continue
		into[id] = d
		files[f] = id


func _load_codex() -> void:
	var dir_path: String = root.path_join("codex")
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		errors.append("missing folder data/codex")
		return
	for f: String in dir.get_files():
		if f.ends_with(".md"):
			codex[f.get_basename()] = FileAccess.get_file_as_string(dir_path.path_join(f))


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("missing file %s" % path.trim_prefix("res://"))
		return null
	var parse_errors: Array[String] = []
	var v: Variant = CanonicalJson.parse(FileAccess.get_file_as_string(path), parse_errors)
	for e: String in parse_errors:
		errors.append("%s: %s" % [path.trim_prefix("res://"), e])
	if typeof(v) != TYPE_DICTIONARY:
		if parse_errors.is_empty():
			errors.append("%s: top level is not an object" % path.trim_prefix("res://"))
		return null
	return v
