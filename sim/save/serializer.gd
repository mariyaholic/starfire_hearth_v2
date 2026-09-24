class_name SaveSerializer
extends RefCounted
## Save files (§9.6): canonical JSON of
##   {format, version, game_version, seed, turn, scenario_id, state, rng_meta, checksum}
## where checksum is the SHA-256 of the canonical JSON of `state`. Loading verifies the checksum,
## then runs the migration chain up to the current version.
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


static func current_version() -> int:
	return GameState.SCHEMA_VERSION


static func rng_meta() -> Dictionary:
	return {
		"algorithm": "xoshiro128**",
		"seeding": "splitmix32 over fmix32(seed, turn, stream, salt)",
		"streams": "stateless",
	}


## The full save text for a state. Returns "" if the state cannot be serialised (a float leaked in).
static func to_text(state: GameState, game_version: String) -> String:
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
	return CanonicalJson.stringify(envelope)


static func from_text(text: String) -> LoadResult:
	var lr: LoadResult = LoadResult.new()
	var errors: Array[String] = []
	var parsed: Variant = CanonicalJson.parse(text, errors)
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
	lr.ok = true
	return lr
