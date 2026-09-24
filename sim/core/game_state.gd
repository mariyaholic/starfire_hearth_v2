class_name GameState
extends RefCounted
## Root of the simulation state: a tree of typed RefCounted objects. Everything the rules need to
## reproduce a turn lives here; nothing else is saved.

## Bump when the shape of to_dict() changes, and add a migration in sim/save/migrations/.
const SCHEMA_VERSION: int = 1
const MAX_SEED: int = 0xFFFFFFFF

var game_seed: int = 0
var turn: int = 1
var scenario_id: String = ""
var player_id: String = ""
var empires: Dictionary[String, Empire] = {}
var systems: Dictionary[String, StarSystem] = {}
var lanes: Dictionary[String, Lane] = {}
var planets: Dictionary[String, Planet] = {}
var colonies: Dictionary[String, Colony] = {}
var fleets: Dictionary[String, Fleet] = {}
var ships: Dictionary[String, Ship] = {}
var designs: Dictionary[String, Design] = {}
## Global story flags: flag -> value (usually the turn it was set).
var flags: Dictionary[String, int] = {}
## Id counters per prefix, for next_id().
var counters: Dictionary[String, int] = {}


## Allocates a new stable id such as "col_0007".
func next_id(prefix: String) -> String:
	var n: int = counters.get(prefix, 0) + 1
	counters[prefix] = n
	return "%s_%04d" % [prefix, n]


func player() -> Empire:
	return empires.get(player_id, null)


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"game_seed": game_seed,
		"turn": turn,
		"scenario_id": scenario_id,
		"player_id": player_id,
		"empires": _collection_to_dict(empires),
		"systems": _collection_to_dict(systems),
		"lanes": _collection_to_dict(lanes),
		"planets": _collection_to_dict(planets),
		"colonies": _collection_to_dict(colonies),
		"fleets": _collection_to_dict(fleets),
		"ships": _collection_to_dict(ships),
		"designs": _collection_to_dict(designs),
		"flags": DictIO.plain(flags),
		"counters": DictIO.plain(counters),
	}


static func from_dict(d: Dictionary) -> GameState:
	var s: GameState = GameState.new()
	s.game_seed = DictIO.int_of(d, "game_seed")
	s.turn = DictIO.int_of(d, "turn", 1)
	s.scenario_id = DictIO.str_of(d, "scenario_id")
	s.player_id = DictIO.str_of(d, "player_id")
	var src: Dictionary = DictIO.dict_of(d, "empires")
	for k: String in DictIO.sorted_keys(src):
		s.empires[k] = Empire.from_dict(src[k])
	src = DictIO.dict_of(d, "systems")
	for k: String in DictIO.sorted_keys(src):
		s.systems[k] = StarSystem.from_dict(src[k])
	src = DictIO.dict_of(d, "lanes")
	for k: String in DictIO.sorted_keys(src):
		s.lanes[k] = Lane.from_dict(src[k])
	src = DictIO.dict_of(d, "planets")
	for k: String in DictIO.sorted_keys(src):
		s.planets[k] = Planet.from_dict(src[k])
	src = DictIO.dict_of(d, "colonies")
	for k: String in DictIO.sorted_keys(src):
		s.colonies[k] = Colony.from_dict(src[k])
	src = DictIO.dict_of(d, "fleets")
	for k: String in DictIO.sorted_keys(src):
		s.fleets[k] = Fleet.from_dict(src[k])
	src = DictIO.dict_of(d, "ships")
	for k: String in DictIO.sorted_keys(src):
		s.ships[k] = Ship.from_dict(src[k])
	src = DictIO.dict_of(d, "designs")
	for k: String in DictIO.sorted_keys(src):
		s.designs[k] = Design.from_dict(src[k])
	s.flags = DictIO.int_map(d, "flags")
	s.counters = DictIO.int_map(d, "counters")
	return s


## Deep copy through the serialised form, so a clone can never share mutable state.
func clone() -> GameState:
	return GameState.from_dict(to_dict())


## SHA-256 of the canonical JSON of this state. Empty string if the state holds a non-integer.
func state_hash() -> String:
	var text: String = CanonicalJson.stringify(to_dict())
	if text.is_empty():
		return ""
	return CanonicalJson.sha256_hex(text)


static func _collection_to_dict(c: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in DictIO.sorted_keys(c):
		var obj: Variant = c[k]
		out[k] = obj.to_dict()
	return out
