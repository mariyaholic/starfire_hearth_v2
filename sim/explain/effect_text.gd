class_name EffectText
extends RefCounted
## Describes effect records (§13.3) as string keys and arguments, for event choices, techs,
## buildings, ordinances and the Codex. The simulation decides what to say; the string layer
## formats the numbers (argument suffixes: _sp signed points, _sc signed centi-units, _bp signed
## percentage).

## One readable effect: a main phrase, and optional scope and duration phrases.
class Line:
	extends RefCounted
	var key: String = ""
	var args: Dictionary = {}
	var scope_key: String = ""
	var scope_args: Dictionary = {}
	var time_key: String = ""
	var time_args: Dictionary = {}
	## Whether the effect helps (true) or hurts (false), for the icon beside it.
	var good: bool = true


## Lines for a list of effect records; effects with nothing to say (flags) are skipped.
static func describe_all(state: GameState, effects: Array, colony_id: String = "") -> Array[Line]:
	var out: Array[Line] = []
	for fx: Variant in effects:
		if typeof(fx) != TYPE_DICTIONARY:
			continue
		var l: Line = describe(state, fx, colony_id)
		if l != null:
			out.append(l)
	return out


static func describe(state: GameState, d: Dictionary, colony_id: String = "") -> Line:
	var db: ContentDb = Content.db()
	var key: String = DictIO.str_of(d, "key")
	var v: int = DictIO.int_of(d, "value")
	var target: String = DictIO.str_of(d, "target")
	var l: Line = Line.new()
	l.good = v >= 0
	var param: String = key.get_slice(":", 1) if key.contains(":") else ""
	var head: String = key.get_slice(":", 0)
	match head:
		"stability_add":
			_fill(l, "effect.stability", {"value_sp": v})
		"output_bp":
			_fill(l, "effect.output", {"value_bp": v})
		"resource_output_bp":
			_fill(l, "effect.resource_output", {"value_bp": v, "resource_key": _res(param)})
		"district_output_bp":
			_fill(l, "effect.district_output", {"value_bp": v, "district_key": DictIO.str_of(db.record("districts", param), "name_key")})
		"research_bp":
			if param == "all":
				_fill(l, "effect.research", {"value_bp": v})
			else:
				_fill(l, "effect.research_branch", {"value_bp": v, "branch_key": Names.branch(param)})
		"growth_bp":
			_fill(l, "effect.growth", {"value_bp": v})
		"housing_add":
			_fill(l, "effect.housing", {"value_sp": v})
		"influence_per_turn_add":
			_fill(l, "effect.influence_per_turn", {"value_sc": v})
		"output_add":
			_fill(l, "effect.output_add", {"value_sc": v, "resource_key": _res(param)})
		"add_stock":
			_fill(l, "effect.stock", {"value_sc": v, "resource_key": _res(param)})
		"cap_add":
			_fill(l, "effect.cap", {"value_sc": v, "resource_key": _res(param)})
		"add_pops":
			_fill(l, "effect.pops", {"value_sp": v})
		"remove_pops":
			_fill(l, "effect.pops", {"value_sp": -v})
			l.good = false
		"decode_progress_add":
			_fill(l, "effect.decode", {"value_sc": v})
		"decode_rate_bp":
			_fill(l, "effect.decode_rate", {"value_bp": v})
		"add_building":
			_fill(l, "effect.building", {"name_key": DictIO.str_of(db.record("buildings", target), "name_key")})
		"rejoin_colony":
			_fill(l, "effect.rejoin", {})
		"edict_slots_add":
			_fill(l, "effect.ordinance_slots", {"value_sp": v})
		"outpost_cost_bp":
			_fill(l, "effect.outpost_cost", {"value_bp": v})
			l.good = v <= 0
		"outpost_time_bp":
			_fill(l, "effect.outpost_time", {"value_bp": v})
			l.good = v <= 0
		"sensor_range_add":
			_fill(l, "effect.sensor", {"value_sp": v})
		"noise_add":
			_fill(l, "effect.noise", {"value_sc": v})
			l.good = v <= 0
		"noise_transit_bp":
			_fill(l, "effect.noise_transit", {"value_bp": v})
			l.good = v <= 0
		"slots_add":
			_fill(l, "effect.slots", {"value_sp": v})
		"ship_cost_bp":
			_fill(l, "effect.ship_cost", {"value_bp": v})
			l.good = v <= 0
		"opinion_add":
			_fill(l, "effect.opinion", {"value_sp": v, "faction_key": DictIO.str_of(db.record("factions", param), "name_key")})
		"damage_bp":
			_fill(l, "effect.damage", {"value_bp": v, "type_key": Names.damage(param)})
		"hit_chance_bp":
			_fill(l, "effect.hit_chance", {"value_bp": v})
		"clear_blocked_slot":
			_fill(l, "effect.clear_blocked", {})
		"add_trait":
			_fill(l, "effect.add_trait", {"name_key": DictIO.str_of(db.record("traits", target), "name_key")})
		"remove_trait":
			_fill(l, "effect.remove_trait", {"name_key": DictIO.str_of(db.record("traits", target), "name_key")})
			l.good = true
		_:
			return null
	var turns: int = DictIO.int_of(d, "turns", 0)
	var over: int = DictIO.int_of(d, "over_turns", 0)
	if over > 1:
		l.time_key = "effect.time.over"
		l.time_args = {"turns": over}
	elif turns > 0:
		l.time_key = "effect.time.for"
		l.time_args = {"turns": turns}
	elif Effects.is_lasting(key) and state != null:
		l.time_key = "effect.time.permanent"
	if target == "colony" and state != null:
		var cid: String = colony_id
		if cid.is_empty() or not state.colonies.has(cid):
			var e: Empire = state.player()
			cid = e.capital_id if e != null else ""
		if state.colonies.has(cid):
			l.scope_key = "effect.scope.colony"
			l.scope_args = ColonyRules.name_args(state, state.colonies[cid])
	return l


static func _fill(l: Line, key: String, args: Dictionary) -> void:
	l.key = key
	l.args = args


static func _res(res_id: String) -> String:
	return DictIO.str_of(Content.db().record("resources", res_id), "name_key", "res.%s.name" % res_id)
