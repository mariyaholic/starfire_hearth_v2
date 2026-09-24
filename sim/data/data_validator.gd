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
	if DictIO.str_of(sc, "status") == "playable":
		_check_playable(sid, sc, w)


## The parts a playable scenario needs: objectives, tutorial, events, legacies, loss rules and
## the balance scope.
func _check_playable(_sid: String, sc: Dictionary, w: String) -> void:
	for k: String in ["briefing_key", "debrief_key"]:
		_check_key(sc.get(k), "%s.%s" % [w, k])
	if DictIO.int_of(sc, "expected_turns") < 10:
		error(w, "expected_turns must be at least 10")
	var objs: Dictionary = DictIO.dict_of(sc, "objectives")
	var obj_ids: Dictionary[String, bool] = {}
	if DictIO.arr_of(objs, "required").is_empty():
		error(w, "a playable scenario needs at least one required objective")
	for group: String in ["required", "optional"]:
		for ov: Variant in DictIO.arr_of(objs, group):
			var od: Dictionary = ov
			var id: String = DictIO.str_of(od, "id")
			var ow: String = "%s.objectives.%s" % [w, id]
			if id.is_empty() or obj_ids.has(id):
				error(ow, "objective ids must be present and unique")
			obj_ids[id] = true
			_check_key(od.get("text_key"), ow + ".text_key")
			var type: String = DictIO.str_of(od, "type")
			if not Objectives.TYPES.has(type):
				error(ow, "unknown objective type \"%s\"" % type)
			if type in ["flag", "never_flag"] and DictIO.str_of(od, "flag").is_empty():
				error(ow, "a flag objective names its flag")
	var tut_ids: Dictionary[String, bool] = {}
	for tv: Variant in DictIO.arr_of(sc, "tutorial"):
		var td: Dictionary = tv
		var id: String = DictIO.str_of(td, "id")
		var tw: String = "%s.tutorial.%s" % [w, id]
		if not id.begins_with("t_") or tut_ids.has(id):
			error(tw, "tutorial step ids start with t_ and are unique")
		tut_ids[id] = true
		_check_key(td.get("text_key"), tw + ".text_key")
		var done: Dictionary = DictIO.dict_of(td, "complete_on")
		if not done.has("ui") and not done.has("state"):
			error(tw, "complete_on needs a ui or state condition")
		if done.has("state") and not Tutorial.is_known_condition(DictIO.str_of(done, "state")):
			error(tw, "unknown state condition \"%s\"" % DictIO.str_of(done, "state"))
	for cid: Variant in DictIO.arr_of(sc, "scripted_events"):
		if not db.events.has(str(cid)):
			error(w, "scripted event chain \"%s\" has no file in data/events" % str(cid))
	for lid: Variant in DictIO.arr_of(sc, "legacies"):
		if not db.has("legacies", str(lid)):
			error(w, "unknown legacy \"%s\"" % str(lid))
	if DictIO.arr_of(sc, "loss").is_empty():
		error(w, "a playable scenario needs a loss rule")
	for lv: Variant in DictIO.arr_of(sc, "loss"):
		if not Objectives.LOSS_TYPES.has(DictIO.str_of(lv, "type")):
			error(w, "unknown loss type \"%s\"" % DictIO.str_of(lv, "type"))
	for o: Variant in DictIO.arr_of(sc, "locked_ordinances"):
		if not db.has("edicts", str(o)):
			error(w, "unknown ordinance \"%s\" in locked_ordinances" % str(o))
	var scope: Dictionary = DictIO.dict_of(sc, "balance_scope")
	for pair: Array in [["districts", "districts"], ["buildings", "buildings"], ["techs", "techs"]]:
		for id: Variant in DictIO.arr_of(scope, pair[0]):
			if not db.has(pair[1], str(id)):
				error(w, "balance_scope lists unknown %s \"%s\"" % [pair[0], str(id)])


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
	var hands: Dictionary = DictIO.dict_of(ed, "research_hands")
	for b: Variant in hands.keys():
		if not Empire.BRANCHES.has(str(b)):
			error(ew, "research_hands has unknown branch \"%s\"" % str(b))
			continue
		for t: Variant in hands[b]:
			if not db.has("techs", str(t)) or DictIO.str_of(db.record("techs", str(t)), "branch") != str(b):
				error(ew, "research hand %s lists \"%s\", which is not a %s tech" % [str(b), str(t), str(b)])
	for sv: Variant in DictIO.arr_of(ed, "ships"):
		var shd: Dictionary = sv
		if not db.has("hulls", DictIO.str_of(shd, "hull")):
			error(ew, "unknown hull \"%s\"" % DictIO.str_of(shd, "hull"))
		if not systems.has(DictIO.str_of(shd, "system")):
			error(ew, "ship system %s is not on the map" % DictIO.str_of(shd, "system"))
	for pv: Variant in DictIO.arr_of(ed, "surveyed"):
		if not planets.has(str(pv)):
			error(ew, "surveyed planet %s is not on the map" % str(pv))
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
		for bv: Variant in DictIO.arr_of(cd, "buildings"):
			var bd: Dictionary = bv
			var bid: String = DictIO.str_of(bd, "building")
			var bslot: int = DictIO.int_of(bd, "slot", -2)
			if not db.has("buildings", bid):
				error(cw, "unknown building \"%s\"" % bid)
				continue
			if DictIO.bool_of(db.record("buildings", bid), "landmark"):
				if bslot != -1:
					error(cw, "landmark %s takes no slot (slot -1)" % bid)
				continue
			if bslot < 0 or bslot >= slots or blocked.has(bslot) or used.has(bslot):
				error(cw, "building %s slot %d is invalid, blocked or taken" % [bid, bslot])
			used[bslot] = true
		if DictIO.int_of(cd, "pops", -1) < 0:
			error(cw, "pops must be 0 or more")


const EVENT_KINDS: Array[String] = ["scripted", "main_arc", "status", "emergent"]
const EXPRESSIONS: Array[String] = ["neutral", "warm", "worried", "stern"]
const BODY_WORDS_MIN: int = 60
const BODY_WORDS_MAX: int = 140


func _check_events() -> void:
	for cid: String in DictIO.sorted_keys(db.events):
		_check_chain(cid, db.events[cid])


func _check_chain(cid: String, chain: Dictionary) -> void:
	var w: String = "events/" + cid
	if DictIO.int_of(chain, "version", -1) != 1:
		error(w, "top-level \"version\" must be 1")
	if not EVENT_KINDS.has(DictIO.str_of(chain, "kind")):
		error(w, "kind must be one of %s" % ", ".join(EVENT_KINDS))
	for sid: Variant in DictIO.arr_of(chain, "scenarios"):
		if not db.scenarios.has(str(sid)):
			error(w, "unknown scenario \"%s\"" % str(sid))
	var vignette: String = DictIO.str_of(chain, "vignette")
	if not vignette.is_empty() and not db.has("vignettes", vignette):
		error(w, "vignette \"%s\" is not in vignettes.json" % vignette)
	var steps: Dictionary[int, Dictionary] = {}
	for sv: Variant in DictIO.arr_of(chain, "steps"):
		var sd: Dictionary = sv
		var n: int = DictIO.int_of(sd, "step", 0)
		if n < 1 or steps.has(n):
			error(w, "step numbers start at 1 and are unique")
		steps[n] = sd
	if not steps.has(1):
		error(w, "a chain needs a step 1")
	for n: int in steps.keys():
		_check_step(cid, n, steps[n], steps)


func _check_step(cid: String, n: int, sd: Dictionary, steps: Dictionary[int, Dictionary]) -> void:
	var w: String = "events/%s.step%d" % [cid, n]
	_check_key(sd.get("title_key"), w + ".title_key")
	_check_key(sd.get("body_key"), w + ".body_key")
	if sd.has("hint_key"):
		_check_key(sd["hint_key"], w + ".hint_key")
	var body: String = strings.entries.get(DictIO.str_of(sd, "body_key"), "")
	var words: int = body.split(" ", false).size()
	if not body.is_empty() and (words < BODY_WORDS_MIN or words > BODY_WORDS_MAX):
		error(w, "the body has %d words; event bodies are %d to %d words (section 10.6)" % [words, BODY_WORDS_MIN, BODY_WORDS_MAX])
	_check_trigger(DictIO.dict_of(sd, "trigger"), w + ".trigger")
	var speaker: String = DictIO.str_of(sd, "speaker")
	if not speaker.is_empty() and not db.has("portraits", speaker):
		error(w, "speaker \"%s\" is not in portraits.json" % speaker)
	if sd.has("expression") and not EXPRESSIONS.has(DictIO.str_of(sd, "expression")):
		error(w, "expression must be one of %s" % ", ".join(EXPRESSIONS))
	var music: String = DictIO.str_of(sd, "music")
	if not music.is_empty() and DictIO.str_of(db.record("assets", music), "kind") != "music":
		error(w, "music cue \"%s\" is not a music id in asset_manifest.json" % music)
	var on_fire: Dictionary = DictIO.dict_of(sd, "on_fire")
	_check_effects(DictIO.arr_of(on_fire, "effects"), w + ".on_fire.effects")
	var choices: Array = DictIO.arr_of(sd, "choices")
	if choices.size() > 4:
		error(w, "a step has at most 4 choices")
	for i in choices.size():
		var cw: String = "%s.choice%d" % [w, i]
		if typeof(choices[i]) != TYPE_DICTIONARY:
			error(cw, "a choice is an object")
			continue
		var ch: Dictionary = choices[i]
		_check_key(ch.get("label_key"), cw + ".label_key")
		if ch.has("cost"):
			_check_value(ch["cost"], "res_map", cw + ".cost")
		_check_effects(DictIO.arr_of(ch, "effects"), cw + ".effects")
		if ch.has("requires"):
			_check_trigger(DictIO.dict_of(ch, "requires"), cw + ".requires")
		if ch.has("locked_key"):
			_check_key(ch["locked_key"], cw + ".locked_key")
		_check_next(DictIO.dict_of(ch, "next"), steps, cw)
		var outcomes: Array = DictIO.arr_of(ch, "outcomes")
		if not outcomes.is_empty():
			var sum: int = 0
			for j in outcomes.size():
				var od: Dictionary = outcomes[j]
				var ow: String = "%s.outcome%d" % [cw, j]
				sum += DictIO.int_of(od, "chance_bp")
				_check_key(od.get("text_key"), ow + ".text_key")
				_check_effects(DictIO.arr_of(od, "effects"), ow + ".effects")
				_check_next(DictIO.dict_of(od, "next"), steps, ow)
			if sum != 10000:
				error(cw, "outcome chances add up to %d, not 10000" % sum)
			if not DictIO.bool_of(ch, "uncertain"):
				error(cw, "a choice with outcomes is marked \"uncertain\"")


func _check_next(next: Dictionary, steps: Dictionary[int, Dictionary], w: String) -> void:
	if next.is_empty():
		return
	if not steps.has(DictIO.int_of(next, "step")):
		error(w, "next step %d does not exist" % DictIO.int_of(next, "step"))
	if DictIO.int_of(next, "delay_turns", 1) < 1:
		error(w, "delay_turns is at least 1")


func _check_trigger(trig: Dictionary, w: String) -> void:
	for k: Variant in trig.keys():
		if not Events.CONDITIONS.has(str(k)) and not ["weight", "scripted", "chance_bp"].has(str(k)):
			error(w, "unknown trigger condition \"%s\"" % str(k))
	for t: Variant in DictIO.arr_of(trig, "techs_all"):
		if not db.has("techs", str(t)):
			error(w, "unknown tech \"%s\"" % str(t))
	if trig.has("has_building") and not db.has("buildings", DictIO.str_of(trig, "has_building")):
		error(w, "unknown building \"%s\"" % DictIO.str_of(trig, "has_building"))
	if trig.has("has_district") and not db.has("districts", DictIO.str_of(trig, "has_district")):
		error(w, "unknown district \"%s\"" % DictIO.str_of(trig, "has_district"))


## For every playable scenario, walks what can be reached from its start: techs through their
## prerequisites (inside the scenario's tech pool), buildings through their unlocking tech or a
## story event, and district tiers through their tech. Everything in the balance scope must be
## reachable.
func _check_reachability() -> void:
	var playable: Array[String] = []
	for sid: String in DictIO.sorted_keys(db.scenarios):
		if DictIO.str_of(db.scenarios[sid], "status") == "playable":
			playable.append(sid)
	if playable.is_empty():
		skip("reachability", "no playable scenario yet, so district and building reachability is not checked")
		return
	for sid: String in playable:
		_check_scenario_reach(sid, db.scenarios[sid])


func _check_scenario_reach(sid: String, sc: Dictionary) -> void:
	var w: String = "scenarios/%s.reachability" % sid
	var no_military: bool = DictIO.bool_of(DictIO.dict_of(sc, "tech_pool"), "exclude_military")
	var techs: Dictionary[String, bool] = {}
	var buildings: Dictionary[String, bool] = {}
	for ev: Variant in DictIO.arr_of(DictIO.dict_of(sc, "start"), "empires"):
		if not DictIO.bool_of(ev, "is_player"):
			continue
		for t: Variant in DictIO.arr_of(ev, "techs"):
			techs[str(t)] = true
		for cv: Variant in DictIO.arr_of(ev, "colonies"):
			for bv: Variant in DictIO.arr_of(cv, "buildings"):
				buildings[DictIO.str_of(bv, "building")] = true
	var grew: bool = true
	while grew:
		grew = false
		for tid: String in db.ids("techs"):
			if techs.has(tid):
				continue
			var t: Dictionary = db.record("techs", tid)
			if no_military and DictIO.bool_of(t, "military"):
				continue
			var ok: bool = true
			for p: String in DictIO.str_arr(t, "prereqs"):
				if not techs.has(p):
					ok = false
			if ok:
				techs[tid] = true
				grew = true
	for bid: String in db.ids("buildings"):
		var b: Dictionary = db.record("buildings", bid)
		if DictIO.bool_of(b, "story"):
			continue
		var tech: String = DictIO.str_of(b, "unlock_tech")
		if tech.is_empty() or techs.has(tech):
			buildings[bid] = true
	for cid: Variant in DictIO.arr_of(sc, "scripted_events"):
		for step: Variant in DictIO.arr_of(db.events.get(str(cid), {}), "steps"):
			var fx: Array = DictIO.arr_of(DictIO.dict_of(step, "on_fire"), "effects").duplicate()
			for ch: Variant in DictIO.arr_of(step, "choices"):
				fx.append_array(DictIO.arr_of(ch, "effects"))
			for e: Variant in fx:
				if DictIO.str_of(e, "key") == "add_building":
					buildings[DictIO.str_of(e, "target")] = true
	var scope: Dictionary = DictIO.dict_of(sc, "balance_scope")
	for tid: Variant in DictIO.arr_of(scope, "techs"):
		if not techs.has(str(tid)):
			error(w, "tech \"%s\" is in the balance scope but cannot be researched" % str(tid))
	for bid2: Variant in DictIO.arr_of(scope, "buildings"):
		if not buildings.has(str(bid2)):
			error(w, "building \"%s\" is in the balance scope but cannot be built" % str(bid2))
	for did: String in db.ids("districts"):
		for tv: Variant in DictIO.arr_of(db.record("districts", did), "tiers"):
			var req: String = DictIO.str_of(tv, "requires_tech")
			if not req.is_empty() and not techs.has(req) and DictIO.arr_of(scope, "districts").has(did):
				error(w, "%s tier %d needs %s, which cannot be researched here" % [did, DictIO.int_of(tv, "tier"), req])
