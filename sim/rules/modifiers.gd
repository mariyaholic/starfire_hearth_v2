class_name Modifiers
extends RefCounted
## Gathers the effects that act on a colony or an empire, each tagged with its source so it can
## become one breakdown line (§6.1). Percentages from the same level add up (DESIGN_LOG 53).
##
## Scopes:
## - empire_wide(): techs, active ordinances, the origin, legacies and empire-wide event
##   modifiers. They act on every colony of the empire.
## - for_colony(): the empire-wide effects, plus the colony's planet type, traits, buildings and
##   colony modifiers, the stability band and the difficulty.
## - empire_buildings(): every building the empire owns, for the keys that act on the empire as
##   a whole (storage caps, influence, decoding).

const STABLE_AT: int = 70
const STABLE_BP: int = 1000
const UNSTABLE_AT: int = 30
const UNSTABLE_BP: int = -1500


## One effect from one source.
class Entry:
	extends RefCounted
	var key: String = ""
	var value: int = 0
	var target: String = ""
	var source_key: String = ""
	var source_args: Dictionary = {}
	## Codex id of the source, such as "tech:hydroponics".
	var link: String = ""


static func empire_wide(state: GameState, empire: Empire) -> Array[Entry]:
	var db: ContentDb = Content.db()
	var out: Array[Entry] = []
	if empire == null:
		return out
	var origin: Dictionary = db.record("origins", empire.origin_id)
	if not origin.is_empty():
		_add_effects(out, DictIO.arr_of(origin, "effects"), "source.effect.origin",
			{"name_key": DictIO.str_of(origin, "name_key")}, "origin:" + empire.origin_id)
	for lid: String in empire.legacies:
		var lg: Dictionary = db.record("legacies", lid)
		_add_effects(out, DictIO.arr_of(lg, "effects"), "source.effect.legacy",
			{"name_key": DictIO.str_of(lg, "name_key")}, "legacy:" + lid)
	for tid: String in empire.techs:
		var tech: Dictionary = db.record("techs", tid)
		_add_effects(out, DictIO.arr_of(tech, "effects"), "source.effect.tech",
			{"name_key": DictIO.str_of(tech, "name_key")}, "tech:" + tid)
	for oid: String in DictIO.sorted_keys(empire.ordinances):
		var ord: Dictionary = db.record("edicts", oid)
		_add_effects(out, DictIO.arr_of(ord, "effects"), "source.effect.ordinance",
			{"name_key": DictIO.str_of(ord, "name_key")}, "edict:" + oid)
	for mid: String in DictIO.sorted_keys(state.modifiers):
		var m: Modifier = state.modifiers[mid]
		if m.empire_id == empire.id and m.colony_id.is_empty():
			_add_modifier(out, m)
	return out


static func for_colony(state: GameState, colony: Colony) -> Array[Entry]:
	var db: ContentDb = Content.db()
	var empire: Empire = state.empires.get(colony.owner_id, null)
	var out: Array[Entry] = empire_wide(state, empire)
	var planet: Planet = state.planets.get(colony.planet_id, null)
	if planet != null:
		var pt: Dictionary = db.record("planet_types", planet.type)
		_add_effects(out, DictIO.arr_of(pt, "effects"), "source.effect.planet_type",
			{"name_key": DictIO.str_of(pt, "name_key")}, "planet_type:" + planet.type)
		for trait_id: String in planet.traits:
			var tr: Dictionary = db.record("traits", trait_id)
			_add_effects(out, DictIO.arr_of(tr, "effects"), "source.effect.trait",
				{"name_key": DictIO.str_of(tr, "name_key")}, "trait:" + trait_id)
	for pb: Colony.PlacedBuilding in colony.buildings:
		var bld: Dictionary = db.record("buildings", pb.building_id)
		_add_effects(out, DictIO.arr_of(bld, "effects"), "source.effect.building",
			{"name_key": DictIO.str_of(bld, "name_key")}, "building:" + pb.building_id)
	for mid: String in DictIO.sorted_keys(state.modifiers):
		var m: Modifier = state.modifiers[mid]
		if m.colony_id == colony.id:
			_add_modifier(out, m)
	if not colony.is_outpost():
		if colony.stability >= STABLE_AT:
			out.append(_entry("output_bp", STABLE_BP, "", "source.effect.stable", {"at": STABLE_AT}, "mechanic:stability"))
		elif colony.stability <= UNSTABLE_AT:
			out.append(_entry("output_bp", UNSTABLE_BP, "", "source.effect.unstable", {"at": UNSTABLE_AT}, "mechanic:stability"))
	if empire != null and empire.is_player:
		var diff: Dictionary = db.record("difficulty", state.difficulty_id)
		var bp: int = DictIO.int_of(diff, "player_output_bp", 10000) - 10000
		if bp != 0:
			out.append(_entry("output_bp", bp, "", "source.effect.difficulty",
				{"name_key": DictIO.str_of(diff, "name_key")}, "mechanic:difficulty"))
	return out


static func empire_buildings(state: GameState, empire: Empire) -> Array[Entry]:
	var db: ContentDb = Content.db()
	var out: Array[Entry] = []
	if empire == null:
		return out
	for colony: Colony in state.colonies_of(empire.id):
		for pb: Colony.PlacedBuilding in colony.buildings:
			var bld: Dictionary = db.record("buildings", pb.building_id)
			var args: Dictionary = ColonyRules.name_args(state, colony, "colony")
			args["name_key"] = DictIO.str_of(bld, "name_key")
			_add_effects(out, DictIO.arr_of(bld, "effects"), "source.effect.building_at", args,
				"building:" + pb.building_id)
	return out


## Every entry with exactly this key.
static func with_key(entries: Array[Entry], key: String) -> Array[Entry]:
	var out: Array[Entry] = []
	for e: Entry in entries:
		if e.key == key:
			out.append(e)
	return out


static func total(entries: Array[Entry], key: String) -> int:
	var sum: int = 0
	for e: Entry in entries:
		if e.key == key:
			sum += e.value
	return sum


## Adds one add line per entry with this key (skipping zero values).
static func add_lines(b: Breakdown, entries: Array[Entry], key: String) -> void:
	for e: Entry in entries:
		if e.key == key and e.value != 0:
			b.add(e.source_key, e.value, e.source_args, null, e.link)


## Adds one mult line per entry with this key (skipping zero values).
static func mult_lines(b: Breakdown, entries: Array[Entry], key: String) -> void:
	for e: Entry in entries:
		if e.key == key and e.value != 0:
			b.mult(e.source_key, e.value, e.source_args, null, e.link)


static func _add_effects(out: Array[Entry], effects: Array, source_key: String, args: Dictionary, link: String) -> void:
	for fx: Variant in effects:
		if typeof(fx) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = fx
		out.append(_entry(DictIO.str_of(d, "key"), DictIO.int_of(d, "value"), DictIO.str_of(d, "target"), source_key, args, link))


static func _add_modifier(out: Array[Entry], m: Modifier) -> void:
	var key: String = "source.effect.event" if m.is_permanent() else "source.effect.event_timed"
	var args: Dictionary = {"name_key": m.source_key, "turns": m.turns_left}
	_add_effects(out, m.effects, key, args, "")


static func _entry(key: String, value: int, target: String, source_key: String, args: Dictionary, link: String) -> Entry:
	var e: Entry = Entry.new()
	e.key = key
	e.value = value
	e.target = target
	e.source_key = source_key
	e.source_args = args.duplicate()
	e.link = link
	return e
