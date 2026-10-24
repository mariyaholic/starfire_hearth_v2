class_name Tutorial
extends RefCounted
## The advisor tutorial (§6.4, DESIGN_LOG 62). Steps are scenario data; each completes on a UI
## event (reported by the screen) or on a state condition checked here. Progress is stored as
## "tut:<step id>" flags through AcknowledgeCommand, so it is saved with the game.

## State conditions a step can complete on; a ":" suffix takes an id or a count.
const STATE_CONDITIONS: Array[String] = [
	"queued_district:", "research_picked", "event_answered:", "survey_ordered:", "queued_ship:",
	"colonies:", "governor_on", "ordinance_active", "building:", "outpost_ordered", "flag:",
]


static func is_known_condition(cond: String) -> bool:
	for c: String in STATE_CONDITIONS:
		if c.ends_with(":") and cond.begins_with(c) and cond.length() > c.length():
			return true
		if not c.ends_with(":") and cond == c:
			return true
	return false


static func steps(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in DictIO.arr_of(Content.db().scenarios.get(state.scenario_id, {}), "tutorial"):
		out.append(v)
	return out


static func is_done(state: GameState, step_id: String) -> bool:
	return state.flags.has(AcknowledgeCommand.PREFIX + step_id)


## The step the advisor shows now: the first unfinished one whose turn has come, or {}.
static func current(state: GameState) -> Dictionary:
	for st: Dictionary in steps(state):
		if is_done(state, DictIO.str_of(st, "id")):
			continue
		if DictIO.int_of(st, "turn", 1) <= state.turn:
			return st
		return {}
	return {}


## True when a step's state condition holds (UI conditions are reported by the screens).
static func condition_met(state: GameState, empire_id: String, cond: String) -> bool:
	var e: Empire = state.empires.get(empire_id, null)
	if e == null:
		return false
	var arg: String = cond.get_slice(":", 1) if cond.contains(":") else ""
	var head: String = cond.get_slice(":", 0)
	match head:
		"queued_district":
			for c: Colony in state.colonies_of(empire_id):
				for item: BuildItem in c.queue:
					if item.kind == BuildItem.KIND_DISTRICT and item.def_id == arg:
						return true
			return _district_count(state, empire_id, arg) > _start_district_count(state, arg)
		"research_picked":
			for b: String in DictIO.sorted_keys(e.research):
				if not e.research[b].card.is_empty():
					return true
			return not e.techs.is_empty()
		"event_answered":
			for entry: EventLogEntry in state.event_log:
				if entry.chain == arg and entry.choice >= 0:
					return true
			return false
		"survey_ordered":
			if e.surveyed_planets.has(arg):
				return true
			for sh: Ship in state.ships_of(empire_id):
				if sh.task == Ship.TASK_SURVEY and sh.task_target == arg:
					return true
			return false
		"queued_ship":
			for sh: Ship in state.ships_of(empire_id):
				if sh.hull == arg:
					return true
			for c: Colony in state.colonies_of(empire_id):
				for item: BuildItem in c.queue:
					if item.kind == BuildItem.KIND_SHIP and item.def_id == arg:
						return true
			return ColonyRules.settled(state, empire_id).size() > 1 and arg == "colony_ship"
		"colonies":
			return ColonyRules.settled(state, empire_id).size() >= arg.to_int()
		"governor_on":
			for c: Colony in state.colonies_of(empire_id):
				if c.governor_on:
					return true
			return false
		"ordinance_active":
			return not e.ordinances.is_empty()
		"building":
			for c: Colony in state.colonies_of(empire_id):
				if c.has_building(arg):
					return true
				for item: BuildItem in c.queue:
					if item.kind == BuildItem.KIND_BUILDING and item.def_id == arg:
						return true
			return false
		"outpost_ordered":
			if not ColonyRules.outposts(state, empire_id).is_empty():
				return true
			for sh: Ship in state.ships_of(empire_id):
				if sh.task == Ship.TASK_OUTPOST:
					return true
			return false
		"flag":
			return state.flags.has(arg)
	return false


static func _district_count(state: GameState, empire_id: String, district_id: String) -> int:
	var n: int = 0
	for c: Colony in state.colonies_of(empire_id):
		for pd: Colony.PlacedDistrict in c.districts:
			if pd.district_id == district_id:
				n += 1
	return n


static func _start_district_count(state: GameState, district_id: String) -> int:
	var n: int = 0
	var start: Dictionary = DictIO.dict_of(Content.db().scenarios.get(state.scenario_id, {}), "start")
	for ev: Variant in DictIO.arr_of(start, "empires"):
		if not DictIO.bool_of(ev, "is_player"):
			continue
		for cv: Variant in DictIO.arr_of(ev, "colonies"):
			for dv: Variant in DictIO.arr_of(cv, "districts"):
				if DictIO.str_of(dv, "district") == district_id:
					n += 1
	return n
