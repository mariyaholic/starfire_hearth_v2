class_name Effects
extends RefCounted
## Applies effect records from events and story steps (§13.3). Keys that change a rate (stability,
## output, research, growth, housing, influence) become a Modifier, timed when the record has
## "turns" and permanent otherwise, so they show as one breakdown line named after the event.
## Keys that change the state once (stock, pops, flags, decoding, buildings, planet traits) apply
## at once. A record with "over_turns" is delivered gradually.

const LASTING_PLAIN: Array[String] = [
	"output_bp", "stability_add", "growth_bp", "housing_add", "influence_per_turn_add",
	"outpost_cost_bp", "edict_slots_add",
]
const LASTING_PREFIXES: Array[String] = ["resource_output_bp:", "district_output_bp:", "research_bp:", "output_add:", "cap_add:"]
const REJOIN_STABILITY: int = 40


static func is_lasting(key: String) -> bool:
	if LASTING_PLAIN.has(key):
		return true
	for p: String in LASTING_PREFIXES:
		if key.begins_with(p):
			return true
	return false


## Applies a list of effect records for an empire (and a colony, or its capital when empty).
## `source_key` names the cause in breakdowns and reports. Returns the modifiers created.
static func apply(state: GameState, empire_id: String, colony_id: String, effects: Array, source_key: String, r: TurnResult) -> Array[Modifier]:
	var created: Array[Modifier] = []
	var by_turns: Dictionary[int, Array] = {}
	var scope_colony: Dictionary[int, bool] = {}
	for fx: Variant in effects:
		if typeof(fx) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = fx
		var key: String = DictIO.str_of(d, "key")
		var over: int = DictIO.int_of(d, "over_turns", 0)
		if over > 1:
			_schedule(state, empire_id, colony_id, d, source_key)
		elif is_lasting(key):
			var turns: int = DictIO.int_of(d, "turns", -1)
			if not by_turns.has(turns):
				by_turns[turns] = []
			by_turns[turns].append(_plain_effect(d))
			if DictIO.str_of(d, "target") == "colony":
				scope_colony[turns] = true
		else:
			apply_one(state, empire_id, colony_id, key, DictIO.int_of(d, "value"), DictIO.str_of(d, "target"), source_key, r)
	var turn_keys: Array = by_turns.keys()
	turn_keys.sort()
	for turns: Variant in turn_keys:
		var m: Modifier = Modifier.new()
		m.id = state.next_id("mod")
		m.source_key = source_key
		m.empire_id = empire_id
		m.colony_id = _colony_for(state, empire_id, colony_id) if scope_colony.get(int(turns), false) else ""
		for e: Dictionary in by_turns[turns]:
			m.effects.append(e)
		m.turns_left = int(turns)
		state.modifiers[m.id] = m
		created.append(m)
	return created


## Applies one immediate effect.
static func apply_one(state: GameState, empire_id: String, colony_id: String, key: String, value: int, target: String, source_key: String, r: TurnResult) -> void:
	var e: Empire = state.empires.get(empire_id, null)
	if e == null:
		return
	var cid: String = _colony_for(state, empire_id, colony_id)
	var c: Colony = state.colonies.get(cid, null)
	if key.begins_with("add_stock:"):
		var res: String = key.trim_prefix("add_stock:")
		var after: int = maxi(0, e.stock_of(res) + value)
		var cap: int = DictIO.int_of(Content.db().record("resources", res), "cap", -1)
		if cap >= 0 and r != null and r.reports.has(empire_id):
			cap = r.reports[empire_id].cap_of(res)
		elif cap >= 0:
			cap = Economy.empire(state, empire_id).cap_of(res)
		e.stock[res] = mini(after, cap) if cap >= 0 else after
		return
	match key:
		"add_pops":
			if c != null and not c.is_outpost():
				c.pops += value
				_report(state, e, r, "report.effect_pops", {"count": value, "name_key": source_key}, c)
		"remove_pops":
			if c != null:
				c.pops = maxi(0, c.pops - value)
		"set_flag":
			state.flags[target] = state.turn
		"clear_flag":
			state.flags.erase(target)
		"decode_progress_add":
			e.decode_progress = maxi(0, e.decode_progress + value)
		"add_building":
			if c != null and not c.has_building(target):
				_add_building(state, c, target)
		"clear_blocked_slot":
			if c != null:
				var p: Planet = state.planets[c.planet_id]
				if not p.blocked_slots.is_empty():
					p.blocked_slots.remove_at(0)
		"add_trait":
			if c != null and not state.planets[c.planet_id].traits.has(target):
				state.planets[c.planet_id].traits.append(target)
		"remove_trait":
			if c != null:
				state.planets[c.planet_id].traits.erase(target)
		"rejoin_colony":
			_rejoin(state, empire_id, colony_id, r)
		"spawn_event":
			var ev: EventInstance = EventInstance.new()
			ev.id = state.next_id("evt")
			ev.chain = target
			ev.step = maxi(1, value)
			ev.empire_id = empire_id
			ev.colony_id = colony_id
			ev.turn = state.turn + 1
			ev.cause = "chain"
			state.events_scheduled.append(ev)


## A colony that declared autonomy from this empire rejoins it at stability 40.
static func _rejoin(state: GameState, empire_id: String, colony_id: String, r: TurnResult) -> void:
	var c: Colony = state.colonies.get(colony_id, null)
	if c == null or c.autonomous_from != empire_id:
		return
	c.owner_id = empire_id
	c.autonomous_from = ""
	c.stability = REJOIN_STABILITY
	c.autonomy_turns = 0
	var sys: StarSystem = state.systems[state.planets[c.planet_id].system_id]
	if sys.owner_id.is_empty():
		sys.owner_id = empire_id
	_report(state, state.empires[empire_id], r, "report.rejoined", {}, c)


static func _add_building(state: GameState, c: Colony, building_id: String) -> void:
	var bdef: Dictionary = Content.db().record("buildings", building_id)
	var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
	pb.building_id = building_id
	if DictIO.bool_of(bdef, "landmark"):
		pb.slot = Colony.LANDMARK_SLOT
	else:
		var free: Array[int] = ColonyRules.free_slots(c, state.planets[c.planet_id])
		if free.is_empty():
			return
		pb.slot = free[0]
	c.buildings.append(pb)


static func _schedule(state: GameState, empire_id: String, colony_id: String, d: Dictionary, source_key: String) -> void:
	var se: ScheduledEffect = ScheduledEffect.new()
	se.id = state.next_id("sfx")
	se.key = DictIO.str_of(d, "key")
	se.target = DictIO.str_of(d, "target")
	se.value = DictIO.int_of(d, "value")
	se.empire_id = empire_id
	se.colony_id = _colony_for(state, empire_id, colony_id)
	se.over_turns = DictIO.int_of(d, "over_turns", 1)
	se.source_key = source_key
	state.scheduled_effects.append(se)


## The colony an effect lands on: the given one, else the empire's capital.
static func _colony_for(state: GameState, empire_id: String, colony_id: String) -> String:
	if not colony_id.is_empty() and state.colonies.has(colony_id):
		return colony_id
	var e: Empire = state.empires.get(empire_id, null)
	return e.capital_id if e != null else ""


static func _plain_effect(d: Dictionary) -> Dictionary:
	var out: Dictionary = {"key": DictIO.str_of(d, "key"), "value": DictIO.int_of(d, "value")}
	if d.has("target") and DictIO.str_of(d, "target") != "colony":
		out["target"] = DictIO.str_of(d, "target")
	return out


static func _report(state: GameState, e: Empire, r: TurnResult, key: String, args: Dictionary, c: Colony) -> void:
	if r == null or not e.is_player:
		return
	var a: Dictionary = args.duplicate()
	if c != null:
		a.merge(ColonyRules.name_args(state, c))
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_STORY, 40, key, a).with_severity(ReportItem.SEVERITY_GOOD))
