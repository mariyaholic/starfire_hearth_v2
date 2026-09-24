class_name GameState
extends RefCounted
## Root of the simulation state: a tree of typed RefCounted objects. Everything the rules need to
## reproduce a turn lives here; nothing else is saved.

## Bump when the shape of to_dict() changes, and add a migration in sim/save/migrations/.
const SCHEMA_VERSION: int = 2
const MAX_SEED: int = 0xFFFFFFFF

const OUTCOME_NONE: String = ""
const OUTCOME_WON: String = "won"
const OUTCOME_LOST: String = "lost"

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
## Global story flags: flag -> value (usually the turn it was set). Tutorial steps are stored as
## "tut:<step id>" (DESIGN_LOG 62).
var flags: Dictionary[String, int] = {}
## Id counters per prefix, for next_id().
var counters: Dictionary[String, int] = {}
## Difficulty preset id (data/difficulty.json).
var difficulty_id: String = "normal"
## Lasting effects from events and story steps, by id.
var modifiers: Dictionary[String, Modifier] = {}
## Gradual effects, such as pops arriving over several turns.
var scheduled_effects: Array[ScheduledEffect] = []
## Event steps waiting for a choice, oldest first.
var events_pending: Array[EventInstance] = []
## Event steps due on a later turn.
var events_scheduled: Array[EventInstance] = []
var event_log: Array[EventLogEntry] = []
## Chain id -> the last turn it fired (cooldowns, and "not seen recently" for the director).
var event_memory: Dictionary[String, int] = {}
## The first turn the event director may fire an emergent event again (§5.10).
var director_next: int = 0
## Objective id -> the turn it was completed.
var objectives_done: Dictionary[String, int] = {}
## Objective id -> progress counter (streaks, such as turns in a row at stability 40 or more).
var objective_progress: Dictionary[String, int] = {}
## OUTCOME_WON or OUTCOME_LOST once the scenario ends, with the turn and a string key saying why.
var outcome: String = OUTCOME_NONE
var outcome_turn: int = 0
var outcome_reason: String = ""


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
		"difficulty_id": difficulty_id,
		"modifiers": _collection_to_dict(modifiers),
		"scheduled_effects": _list_to_array(scheduled_effects),
		"events_pending": _list_to_array(events_pending),
		"events_scheduled": _list_to_array(events_scheduled),
		"event_log": _list_to_array(event_log),
		"event_memory": DictIO.plain(event_memory),
		"director_next": director_next,
		"objectives_done": DictIO.plain(objectives_done),
		"objective_progress": DictIO.plain(objective_progress),
		"outcome": outcome,
		"outcome_turn": outcome_turn,
		"outcome_reason": outcome_reason,
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
	s.difficulty_id = DictIO.str_of(d, "difficulty_id", "normal")
	src = DictIO.dict_of(d, "modifiers")
	for k: String in DictIO.sorted_keys(src):
		s.modifiers[k] = Modifier.from_dict(src[k])
	for v: Variant in DictIO.arr_of(d, "scheduled_effects"):
		s.scheduled_effects.append(ScheduledEffect.from_dict(v))
	for v: Variant in DictIO.arr_of(d, "events_pending"):
		s.events_pending.append(EventInstance.from_dict(v))
	for v: Variant in DictIO.arr_of(d, "events_scheduled"):
		s.events_scheduled.append(EventInstance.from_dict(v))
	for v: Variant in DictIO.arr_of(d, "event_log"):
		s.event_log.append(EventLogEntry.from_dict(v))
	s.event_memory = DictIO.int_map(d, "event_memory")
	s.director_next = DictIO.int_of(d, "director_next")
	s.objectives_done = DictIO.int_map(d, "objectives_done")
	s.objective_progress = DictIO.int_map(d, "objective_progress")
	s.outcome = DictIO.str_of(d, "outcome")
	s.outcome_turn = DictIO.int_of(d, "outcome_turn")
	s.outcome_reason = DictIO.str_of(d, "outcome_reason")
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


## The colonies an empire owns, in id order.
func colonies_of(empire_id: String) -> Array[Colony]:
	var out: Array[Colony] = []
	for k: String in DictIO.sorted_keys(colonies):
		if colonies[k].owner_id == empire_id:
			out.append(colonies[k])
	return out


## The ships an empire owns, in id order.
func ships_of(empire_id: String) -> Array[Ship]:
	var out: Array[Ship] = []
	for k: String in DictIO.sorted_keys(ships):
		if ships[k].owner_id == empire_id:
			out.append(ships[k])
	return out


func is_over() -> bool:
	return outcome != OUTCOME_NONE


static func _list_to_array(items: Array) -> Array:
	var out: Array = []
	for obj: Variant in items:
		out.append(obj.to_dict())
	return out


static func _collection_to_dict(c: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in DictIO.sorted_keys(c):
		var obj: Variant = c[k]
		out[k] = obj.to_dict()
	return out
