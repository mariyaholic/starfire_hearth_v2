class_name DataValidator
extends RefCounted
## Schema, cross-reference and content-rule checks over the loaded data (§9.8 "Data").
## Presentation checks (icon files exist, colour tokens exist, code uses of string keys) are added
## by tools/validate_data.gd, which keeps sim/ free of ui/ knowledge.

const SEVERITY_ERROR: String = "error"
const SEVERITY_SKIP: String = "skip"

const SPECTRAL: Array[String] = ["M", "K", "G", "F", "A", "white_dwarf", "binary"]
const SPECIALS: Array[String] = ["nebula", "dormant_beacon", "derelict", "ruins", "rich_asteroids"]
const BEACONS: Array[String] = ["none", "dormant", "active"]
const SCENARIO_STATUS: Array[String] = ["stub", "playable"]
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const HEX_PATTERN: String = "^#[0-9A-Fa-f]{6}$"

var issues: Array[Dictionary] = []
var db: ContentDb
var strings: StringTable
## String keys referenced anywhere in data (filled while checking; used by the orphan check).
var used_keys: Dictionary[String, bool] = {}
## Icon ids and colour tokens referenced by data, for the tool-level checks.
var used_icons: Dictionary[String, String] = {}
var used_tokens: Dictionary[String, String] = {}

var _id_re: RegEx = RegEx.create_from_string(ID_PATTERN)
var _hex_re: RegEx = RegEx.create_from_string(HEX_PATTERN)


static func run(p_db: ContentDb, p_strings: StringTable) -> DataValidator:
	var v: DataValidator = DataValidator.new()
	v.db = p_db
	v.strings = p_strings
	for e: String in p_db.errors:
		v.error("load", e)
	for e: String in p_strings.errors:
		v.error("strings", e)
	v._check_tables()
	v._check_resource_sinks()
	v._check_scenarios()
	v._check_events()
	v._check_reachability()
	return v


func error(where: String, message: String) -> void:
	issues.append({"severity": SEVERITY_ERROR, "where": where, "message": message})


func skip(where: String, message: String) -> void:
	issues.append({"severity": SEVERITY_SKIP, "where": where, "message": message})


func errors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: Dictionary in issues:
		if i["severity"] == SEVERITY_ERROR:
			out.append(i)
	return out


func skips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: Dictionary in issues:
		if i["severity"] == SEVERITY_SKIP:
			out.append(i)
	return out


## String keys in en.csv that nothing references. `code_keys` are keys found as literals in code.
func orphaned_keys(code_keys: Dictionary[String, bool]) -> Array[String]:
	var out: Array[String] = []
	for k: String in strings.keys:
		if not used_keys.has(k) and not code_keys.has(k):
			out.append(k)
	return out


# --- tables -----------------------------------------------------------------------------------

func _check_tables() -> void:
	for tname: String in DataSchema.TABLES.keys():
		var spec: Dictionary = DataSchema.TABLES[tname]
		var fname: String = spec["file"]
		if db.versions.get(fname, -1) != 1:
			error(fname, "top-level \"version\" must be 1")
		for id: String in db.ids(tname):
			_check_object(db.record(tname, id), spec["fields"], "%s:%s" % [fname, id])


func _check_object(rec: Dictionary, fields: Dictionary, where: String) -> void:
	for f: Variant in rec.keys():
		if not fields.has(f):
			error(where, "unknown field \"%s\"" % str(f))
	for f: Variant in fields.keys():
		var ftype: String = fields[f]
		var optional: bool = ftype.begins_with("?")
		ftype = ftype.trim_prefix("?")
		if not rec.has(f) or rec[f] == null:
			if not optional:
				error(where, "missing field \"%s\"" % str(f))
			continue
		_check_value(rec[f], ftype, "%s.%s" % [where, str(f)])


func _check_value(v: Variant, ftype: String, where: String) -> void:
	if ftype.begins_with("list:"):
		if typeof(v) != TYPE_ARRAY:
			error(where, "expected a list")
			return
		var arr: Array = v
		for i in arr.size():
			_check_value(arr[i], ftype.trim_prefix("list:"), "%s[%d]" % [where, i])
		return
	if ftype.begins_with("obj:"):
		if typeof(v) != TYPE_DICTIONARY:
			error(where, "expected an object")
			return
		_check_object(v, DataSchema.OBJECTS.get(ftype.trim_prefix("obj:"), {}), where)
		return
	if ftype.begins_with("ref:"):
		var target: String = ftype.trim_prefix("ref:")
		if typeof(v) != TYPE_STRING or not db.has(target, v):
			error(where, "\"%s\" is not a known %s id" % [str(v), target])
		return
	if ftype.begins_with("enum:"):
		var allowed: PackedStringArray = ftype.trim_prefix("enum:").split("|")
		if typeof(v) != TYPE_STRING or not allowed.has(v):
			error(where, "\"%s\" is not one of %s" % [str(v), ", ".join(allowed)])
		return
	match ftype:
		"id":
			if typeof(v) != TYPE_STRING or _id_re.search(v) == null:
				error(where, "id \"%s\" must be snake_case" % str(v))
		"key":
			_check_key(v, where)
		"str":
			if typeof(v) != TYPE_STRING:
				error(where, "expected text")
		"int", "centi", "bp":
			if typeof(v) != TYPE_INT:
				error(where, "expected a whole number (fixed-point), got %s" % str(v))
		"bool":
			if typeof(v) != TYPE_BOOL:
				error(where, "expected true or false")
		"icon":
			if typeof(v) != TYPE_STRING or _id_re.search(v) == null:
				error(where, "icon id \"%s\" must be snake_case" % str(v))
			else:
				used_icons[v] = where
		"token":
			if typeof(v) != TYPE_STRING:
				error(where, "expected a colour token name")
			else:
				used_tokens[v] = where
		"hex":
			if typeof(v) != TYPE_STRING or _hex_re.search(v) == null:
				error(where, "\"%s\" is not a #RRGGBB colour" % str(v))
		"res_map":
			if typeof(v) != TYPE_DICTIONARY:
				error(where, "expected {resource: amount}")
				return
			var m: Dictionary = v
			for k: Variant in m.keys():
				if not db.has("resources", str(k)):
					error(where, "\"%s\" is not a resource" % str(k))
				if typeof(m[k]) != TYPE_INT:
					error("%s.%s" % [where, str(k)], "expected a whole number of centi-units")
		"effects":
			_check_effects(v, where)
		_:
			error(where, "schema uses unknown type \"%s\"" % ftype)


func _check_key(v: Variant, where: String) -> void:
	if typeof(v) != TYPE_STRING or (v as String).is_empty():
		error(where, "expected a string-table key")
		return
	used_keys[v] = true
	if not strings.entries.has(v):
		error(where, "string key \"%s\" is missing from strings/en.csv" % v)


func _check_effects(v: Variant, where: String) -> void:
	if typeof(v) != TYPE_ARRAY:
		error(where, "expected a list of effects")
		return
	var arr: Array = v
	for i in arr.size():
		var w: String = "%s[%d]" % [where, i]
		if typeof(arr[i]) != TYPE_DICTIONARY:
			error(w, "an effect is an object {key, value, target?}")
			continue
		_check_object(arr[i], DataSchema.OBJECTS["effect"], w)
		var key: String = DictIO.str_of(arr[i], "key")
		if not EffectKeys.is_valid(key):
			error(w, "\"%s\" is not in the closed set of effect keys" % key)


# --- content rules ----------------------------------------------------------------------------

func _check_resource_sinks() -> void:
	for id: String in db.ids("resources"):
		var sinks: Array = DictIO.arr_of(db.record("resources", id), "sinks")
		if sinks.size() < 2:
			error("resources.json:%s" % id, "every resource needs at least 2 competing sinks, found %d" % sinks.size())


func _check_scenarios() -> void:
	if db.scenarios.is_empty():
		error("scenarios", "no scenario files in data/scenarios")
	for f: String in db.scenario_files.keys():
		if f.get_basename() != db.scenario_files[f]:
			error("scenarios/" + f, "file name and id \"%s\" differ" % db.scenario_files[f])
	for sid: String in DictIO.sorted_keys(db.scenarios):
		_check_scenario(sid, db.scenarios[sid])


func _check_scenario(sid: String, sc: Dictionary) -> void:
	var w: String = "scenarios/" + sid
	if DictIO.int_of(sc, "version", -1) != 1:
		error(w, "top-level \"version\" must be 1")
	_check_key(sc.get("name_key"), w + ".name_key")
	_check_key(sc.get("desc_key"), w + ".desc_key")
	if not SCENARIO_STATUS.has(DictIO.str_of(sc, "status")):
		error(w, "status must be one of %s" % ", ".join(SCENARIO_STATUS))
	if not db.has("origins", DictIO.str_of(sc, "origin")):
		error(w, "origin \"%s\" is not a known origin" % DictIO.str_of(sc, "origin"))
	var map: Dictionary = DictIO.dict_of(sc, "map")
	var systems: Dictionary[String, Dictionary] = {}
	var planets: Dictionary[String, Dictionary] = {}
	for s: Variant in DictIO.arr_of(map, "systems"):
		var sd: Dictionary = s
		var sys_id: String = DictIO.str_of(sd, "id")
		var sw: String = "%s.%s" % [w, sys_id]
		if not sys_id.begins_with("sys_") or _id_re.search(sys_id) == null:
			error(sw, "system ids are snake_case and start with sys_")
		if systems.has(sys_id):
			error(sw, "duplicate system id")
		systems[sys_id] = sd
		_check_key(sd.get("name_key"), sw + ".name_key")
		if not SPECTRAL.has(DictIO.str_of(sd, "spectral")):
			error(sw, "unknown spectral class \"%s\"" % DictIO.str_of(sd, "spectral"))
		var mag: int = DictIO.int_of(sd, "magnitude", 0)
		if mag < 1 or mag > 5:
			error(sw, "magnitude must be 1..5")
		if not BEACONS.has(DictIO.str_of(sd, "beacon", "none")):
			error(sw, "unknown beacon state")
		for sp: Variant in DictIO.arr_of(sd, "specials"):
			if not SPECIALS.has(str(sp)):
				error(sw, "unknown special \"%s\"" % str(sp))
		for p: Variant in DictIO.arr_of(sd, "planets"):
			var pd: Dictionary = p
			var pid: String = DictIO.str_of(pd, "id")
			var pw: String = "%s.%s" % [sw, pid]
			if not pid.begins_with("pl_") or _id_re.search(pid) == null:
				error(pw, "planet ids are snake_case and start with pl_")
			if planets.has(pid):
				error(pw, "duplicate planet id")
			planets[pid] = pd
			_check_key(pd.get("name_key"), pw + ".name_key")
			_check_planet(pd, pw)
	for l: Variant in DictIO.arr_of(map, "lanes"):
		var ld: Dictionary = l
		var a: String = DictIO.str_of(ld, "a")
		var b: String = DictIO.str_of(ld, "b")
		if not systems.has(a) or not systems.has(b) or a == b:
			error(w, "lane %s-%s must join two different systems of this map" % [a, b])
		if DictIO.int_of(ld, "length_cly") < 100 or DictIO.int_of(ld, "length_cly") > 600:
			error(w, "lane %s-%s length must be 1.00..6.00 ly (100..600)" % [a, b])
		if not ["deep", "beacon"].has(DictIO.str_of(ld, "kind")):
			error(w, "lane %s-%s kind must be deep or beacon" % [a, b])
	for f: Variant in DictIO.arr_of(map, "fog_locked"):
		if not systems.has(str(f)):
			error(w, "fog_locked system %s is not on the map" % str(f))
	var start: Dictionary = DictIO.dict_of(sc, "start")
	for e: Variant in DictIO.arr_of(start, "empires"):
		_check_start_empire(e, planets, systems, w)


func _check_planet(pd: Dictionary, pw: String) -> void:
	var ptype: String = DictIO.str_of(pd, "type")
	if not db.has("planet_types", ptype):
		error(pw, "\"%s\" is not a planet type" % ptype)
		return
	var hab: String = DictIO.str_of(db.record("planet_types", ptype), "habitability")
	var size: String = DictIO.str_of(pd, "size")
	if hab == "orbital" or hab == "outpost":
		if not size.is_empty():
			error(pw, "gas giants and belts have no size")
	elif not db.has("planet_sizes", size):
		error(pw, "\"%s\" is not a planet size" % size)
	for t: Variant in DictIO.arr_of(pd, "traits"):
		if not db.has("traits", str(t)):
			error(pw, "\"%s\" is not a trait" % str(t))
	var slots: int = DictIO.int_of(db.record("planet_sizes", size), "slots", 0)
	for bs: Variant in DictIO.arr_of(pd, "blocked_slots"):
		if int(bs) < 0 or int(bs) >= slots:
			error(pw, "blocked slot %d outside 0..%d" % [int(bs), slots - 1])


func _check_start_empire(e: Variant, planets: Dictionary[String, Dictionary], systems: Dictionary[String, Dictionary], w: String) -> void:
	if typeof(e) != TYPE_DICTIONARY:
		error(w, "start empire must be an object")
		return
	var ed: Dictionary = e
	var ew: String = "%s.start.%s" % [w, DictIO.str_of(ed, "id")]
	if not DictIO.str_of(ed, "id").begins_with("emp_"):
		error(ew, "empire ids start with emp_")
	if not db.has("factions", DictIO.str_of(ed, "faction")):
		error(ew, "unknown faction \"%s\"" % DictIO.str_of(ed, "faction"))
	if ed.has("origin") and not db.has("origins", DictIO.str_of(ed, "origin")):
		error(ew, "unknown origin \"%s\"" % DictIO.str_of(ed, "origin"))
	_check_value(DictIO.dict_of(ed, "stock"), "res_map", ew + ".stock")
	for s: Variant in DictIO.arr_of(ed, "known_systems"):
		if not systems.has(str(s)):
			error(ew, "known system %s is not on the map" % str(s))
	for t: Variant in DictIO.arr_of(ed, "techs"):
		if not db.has("techs", str(t)):
			error(ew, "unknown tech \"%s\"" % str(t))
	for c: Variant in DictIO.arr_of(ed, "colonies"):
		var cd: Dictionary = c
		var pid: String = DictIO.str_of(cd, "planet")
		var cw: String = "%s.colony@%s" % [ew, pid]
		if not planets.has(pid):
			error(cw, "planet %s is not on the map" % pid)
			continue
		var size: String = DictIO.str_of(planets[pid], "size")
		var slots: int = DictIO.int_of(db.record("planet_sizes", size), "slots", 0)
		var blocked: Array = DictIO.arr_of(planets[pid], "blocked_slots")
		var used: Dictionary[int, bool] = {}
		for d: Variant in DictIO.arr_of(cd, "districts"):
			var dd: Dictionary = d
			var slot: int = DictIO.int_of(dd, "slot", -1)
			if not db.has("districts", DictIO.str_of(dd, "district")):
				error(cw, "unknown district \"%s\"" % DictIO.str_of(dd, "district"))
			if slot < 0 or slot >= slots:
				error(cw, "slot %d outside 0..%d" % [slot, slots - 1])
			if blocked.has(slot):
				error(cw, "slot %d is blocked" % slot)
			if used.has(slot):
				error(cw, "slot %d used twice" % slot)
			used[slot] = true
		if DictIO.int_of(cd, "pops", -1) < 0:
			error(cw, "pops must be 0 or more")


func _check_events() -> void:
	for cid: String in DictIO.sorted_keys(db.events):
		var chain: Dictionary = db.events[cid]
		for step: Variant in DictIO.arr_of(chain, "steps"):
			var sd: Dictionary = step
			for k: String in DataSchema.KEY_FIELDS:
				if sd.has(k):
					_check_key(sd[k], "events/%s.%s" % [cid, k])
			for ch: Variant in DictIO.arr_of(sd, "choices"):
				var chd: Dictionary = ch
				if chd.has("label_key"):
					_check_key(chd["label_key"], "events/%s.choice" % cid)
				_check_effects(DictIO.arr_of(chd, "effects"), "events/%s.choice.effects" % cid)


func _check_reachability() -> void:
	var playable: Array[String] = []
	for sid: String in DictIO.sorted_keys(db.scenarios):
		if DictIO.str_of(db.scenarios[sid], "status") == "playable":
			playable.append(sid)
	if playable.is_empty():
		skip("reachability", "no playable scenario yet, so district and building reachability is not checked")
		return
	# M1 replaces this with a build-graph walk over each playable scenario's techs and events.
	skip("reachability", "reachability walk arrives with the build rules in M1")
