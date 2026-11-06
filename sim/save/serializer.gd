class_name SaveSerializer
extends RefCounted
## Save files (§9.6): canonical JSON of
##   {format, version, game_version, seed, turn, scenario_id, state, rng_meta, checksum}
## where checksum is the SHA-256 of the canonical JSON of `state`. Loading verifies the checksum,
## then runs the migration chain up to the current version.
## Optional presentation/presentation_overlay STRINGS carry independently versioned
## and checked graphics JSON. They never enter GameState or its checksum. Unknown
## graphics are transported unchanged; application code chooses rendering support.
##
## Migrations live in sim/save/migrations/v<N>_to_v<N+1>.gd, each with a single
## `static func migrate(state: Dictionary) -> Dictionary`. Every schema bump also adds a fixture
## save to tests/fixtures/saves/ so the whole chain stays tested. Schema 1 has no migrations.

const FORMAT: String = "starfire-hearth-save"
const MIGRATIONS_DIR: String = "res://sim/save/migrations"


## Outcome of a load. On failure, error_key names a string-table key and error_detail explains
## it for logs.
class LoadResult:
	extends RefCounted
	var ok: bool = false
	var state: GameState = null
	var version_loaded: int = 0
	var game_version: String = ""
	var error_key: String = ""
	var error_detail: String = ""
	var presentation: String = ""
	var presentation_overlay: String = ""
	var presentation_status: String = "missing"


static func current_version() -> int:
	return GameState.SCHEMA_VERSION


static func rng_meta() -> Dictionary:
	return {
		"algorithm": "xoshiro128**",
		"seeding": "splitmix32 over fmix32(seed, turn, stream, salt)",
		"streams": "stateless",
	}


## The full save text for a state. Returns "" if the state cannot be serialised (a float leaked in).
static func to_text(state: GameState, game_version: String, presentation: String = "", presentation_overlay: String = "") -> String:
	var state_dict: Dictionary = state.to_dict()
	var errors: Array[String] = []
	var state_text: String = CanonicalJson.stringify(state_dict, errors)
	if not errors.is_empty():
		push_error("SaveSerializer: state is not serialisable: %s" % ", ".join(errors))
		return ""
	var envelope: Dictionary = {
		"format": FORMAT,
		"version": current_version(),
		"game_version": game_version,
		"seed": state.game_seed,
		"turn": state.turn,
		"scenario_id": state.scenario_id,
		"state": state_dict,
		"rng_meta": rng_meta(),
		"checksum": CanonicalJson.sha256_hex(state_text),
	}
	if not presentation.is_empty(): envelope["presentation"] = presentation
	if not presentation_overlay.is_empty(): envelope["presentation_overlay"] = presentation_overlay
	return CanonicalJson.stringify(envelope)


static func from_text(text: String) -> LoadResult:
	var lr: LoadResult = LoadResult.new()
	var errors: Array[String] = []
	# Inspect optional graphics separately. A bad graphics field never invalidates
	# valid gameplay, while simulation floats and checksums remain strictly checked.
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	var parsed: Variant = json.data
	if parse_error != OK: errors.append("invalid JSON")
	if parsed is Dictionary:
		var raw: Variant = parsed.get("presentation", "")
		lr.presentation = raw if raw is String else JSON.stringify(raw)
		var overlay: Variant = parsed.get("presentation_overlay", "")
		lr.presentation_overlay = overlay if overlay is String else JSON.stringify(overlay)
		lr.presentation_status = PresentationEnvelope.inspect(lr.presentation)["status"]
		parsed.erase("presentation")
		parsed.erase("presentation_overlay")
		parsed = CanonicalJson.ints(parsed, "$", errors)
	if not errors.is_empty() or typeof(parsed) != TYPE_DICTIONARY:
		lr.error_key = "save.error.corrupt"
		lr.error_detail = ", ".join(errors) if not errors.is_empty() else "not a JSON object"
		return lr
	var env: Dictionary = parsed
	if DictIO.str_of(env, "format") != FORMAT:
		lr.error_key = "save.error.not_a_save"
		lr.error_detail = "format is '%s'" % DictIO.str_of(env, "format")
		return lr
	var version: int = DictIO.int_of(env, "version", -1)
	lr.version_loaded = version
	lr.game_version = DictIO.str_of(env, "game_version")
	if version > current_version():
		lr.error_key = "save.error.too_new"
		lr.error_detail = "save version %d, game supports up to %d" % [version, current_version()]
		return lr
	var state_dict: Dictionary = DictIO.dict_of(env, "state")
	var state_text: String = CanonicalJson.stringify(state_dict)
	if state_text.is_empty() or CanonicalJson.sha256_hex(state_text) != DictIO.str_of(env, "checksum"):
		lr.error_key = "save.error.checksum"
		lr.error_detail = "state checksum does not match"
		return lr
	# Check the types consumed by both migrations and from_dict before calling either.
	# A checksum proves only that bytes match; it does not prove they describe a game.
	var shape_error: String = _state_shape_error(state_dict, version)
	if not shape_error.is_empty():
		lr.error_key = "save.error.corrupt"
		lr.error_detail = shape_error
		return lr
	while version < current_version():
		var path: String = "%s/v%d_to_v%d.gd" % [MIGRATIONS_DIR, version, version + 1]
		if not ResourceLoader.exists(path):
			lr.error_key = "save.error.no_migration"
			lr.error_detail = "missing %s" % path
			return lr
		var script: GDScript = load(path)
		state_dict = script.call("migrate", state_dict)
		version += 1
	lr.state = GameState.from_dict(state_dict)
	var problems: Array[String] = Invariants.check(lr.state)
	if not problems.is_empty():
		lr.state = null
		lr.error_key = "save.error.corrupt"
		lr.error_detail = ", ".join(problems)
		return lr
	lr.ok = true
	return lr


## Missing newer fields remain legal for old saves; fields that are present must
## have the types their reconstruction code expects. Unknown fields are ignored.
static func _state_shape_error(state: Dictionary, version: int) -> String:
	for key: String in ["schema_version", "game_seed", "turn", "scenario_id", "player_id", "empires", "systems", "lanes", "planets", "colonies", "fleets", "ships", "designs", "flags", "counters"]:
		if not state.has(key): return "missing state.%s" % key
	if typeof(state["schema_version"]) != TYPE_INT or state["schema_version"] != version:
		return "state schema version does not match envelope"
	return _object_shape_error(state, GameState.new().to_dict(), "state")


static func _object_shape_error(data: Dictionary, template: Dictionary, kind: String) -> String:
	var object_maps: Dictionary = {
		"state.empires": Empire.new().to_dict(), "state.systems": StarSystem.new().to_dict(),
		"state.lanes": Lane.new().to_dict(), "state.planets": Planet.new().to_dict(),
		"state.colonies": Colony.new().to_dict(), "state.fleets": Fleet.new().to_dict(),
		"state.ships": Ship.new().to_dict(), "state.designs": Design.new().to_dict(),
		"state.modifiers": Modifier.new().to_dict(), "empire.research": ResearchBranch.new().to_dict(),
	}
	var object_kinds: Dictionary = {"state.empires":"empire", "state.systems":"system", "state.lanes":"lane", "state.planets":"planet", "state.colonies":"colony", "state.fleets":"fleet", "state.ships":"ship", "state.designs":"design", "state.modifiers":"modifier", "empire.research":"research"}
	var object_arrays: Dictionary = {
		"state.scheduled_effects": ScheduledEffect.new().to_dict(), "state.events_pending": EventInstance.new().to_dict(),
		"state.events_scheduled": EventInstance.new().to_dict(), "state.event_log": EventLogEntry.new().to_dict(),
		"colony.districts": Colony.PlacedDistrict.new().to_dict(), "colony.buildings": Colony.PlacedBuilding.new().to_dict(),
		"colony.queue": BuildItem.new().to_dict(),
	}
	var array_kinds: Dictionary = {"colony.queue":"build_item"}
	var string_maps: Array[String] = ["empire.known_systems"]
	var int_arrays: Array[String] = ["planet.blocked_slots"]
	for key: String in template:
		if not data.has(key): continue
		var value: Variant = data[key]
		var expected: Variant = template[key]
		var field: String = kind + "." + key
		if typeof(value) != typeof(expected): return "invalid type for " + field
		if value is Dictionary:
			if object_maps.has(field):
				for item: Variant in value.values():
					if not item is Dictionary: return "invalid entity in " + field
					var err: String = _object_shape_error(item, object_maps[field], object_kinds[field])
					if not err.is_empty(): return err
			else:
				var value_type: int = TYPE_STRING if string_maps.has(field) else TYPE_INT
				for item: Variant in value.values():
					if typeof(item) != value_type: return "invalid map value in " + field
		elif value is Array:
			if object_arrays.has(field):
				for item: Variant in value:
					if not item is Dictionary: return "invalid item in " + field
					var err: String = _object_shape_error(item, object_arrays[field], array_kinds.get(field, field))
					if not err.is_empty(): return err
			elif field == "modifier.effects":
				for item: Variant in value:
					if not item is Dictionary: return "invalid item in " + field
			else:
				var value_type: int = TYPE_INT if int_arrays.has(field) else TYPE_STRING
				for item: Variant in value:
					if typeof(item) != value_type: return "invalid item in " + field
	return ""
