class_name Ordinances
extends RefCounted
## Ordinances (§5.11; `edicts` in data). Two slots, plus any from techs (Civic Charters). An
## ordinance costs influence to activate and energy every turn while it is active. Timed ones
## run out on their own; the others last until cancelled. Cancelling refunds nothing.

const BASE_SLOTS: int = 2


static func slots(state: GameState, e: Empire) -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.ordinance_slots", Breakdown.UNIT_COUNT, false)
	b.link_to("mechanic:ordinances")
	b.base("source.ordinance_slots_base", BASE_SLOTS)
	Modifiers.add_lines(b, Modifiers.empire_wide(state, e), "edict_slots_add")
	return b.finish()


## Ordinances the scenario keeps locked (Radio Silence waits for Noise in Scenario 2).
static func locked(state: GameState) -> Array[String]:
	return DictIO.str_arr(Content.db().scenarios.get(state.scenario_id, {}), "locked_ordinances")


static func activation_cost(ordinance_id: String) -> Dictionary[String, int]:
	return Construction._res_map(DictIO.dict_of(Content.db().record("edicts", ordinance_id), "activation"))


static func can_activate(state: GameState, empire_id: String, ordinance_id: String) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	var db: ContentDb = Content.db()
	if not db.has("edicts", ordinance_id):
		return Result.fail("error.ordinance.unknown")
	var e: Empire = state.empires[empire_id]
	if locked(state).has(ordinance_id):
		return Result.fail("error.ordinance.locked")
	if e.ordinances.has(ordinance_id):
		return Result.fail("error.ordinance.active")
	var tech: String = DictIO.str_of(db.record("edicts", ordinance_id), "requires_tech")
	if not tech.is_empty() and not e.has_tech(tech):
		return Result.fail("error.build.needs_tech", {"tech_key": DictIO.str_of(db.record("techs", tech), "name_key")})
	var n: int = slots(state, e).total
	if e.ordinances.size() >= n:
		return Result.fail("error.ordinance.no_slot", {"max": n})
	return Construction._check_cost(e, activation_cost(ordinance_id))


static func can_cancel(state: GameState, empire_id: String, ordinance_id: String) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not state.empires[empire_id].ordinances.has(ordinance_id):
		return Result.fail("error.ordinance.not_active")
	return Result.success()


static func activate(state: GameState, e: Empire, ordinance_id: String) -> void:
	var cost: Dictionary[String, int] = activation_cost(ordinance_id)
	for res: String in DictIO.sorted_keys(cost):
		e.stock[res] = e.stock_of(res) - cost[res]
	var duration: int = DictIO.int_of(Content.db().record("edicts", ordinance_id), "duration")
	e.ordinances[ordinance_id] = duration if duration > 0 else -1


static func cancel(e: Empire, ordinance_id: String) -> void:
	e.ordinances.erase(ordinance_id)


## Phase 9, after stability: timed ordinances count down and expire.
static func tick(state: GameState, e: Empire, r: TurnResult) -> void:
	for oid: String in DictIO.sorted_keys(e.ordinances):
		var left: int = e.ordinances[oid]
		if left < 0:
			continue
		left -= 1
		if left > 0:
			e.ordinances[oid] = left
			continue
		e.ordinances.erase(oid)
		if e.is_player:
			var odef: Dictionary = Content.db().record("edicts", oid)
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 45, "report.ordinance_ended", {"name_key": DictIO.str_of(odef, "name_key")})
				.with_severity(ReportItem.SEVERITY_INFO).focus("empire", e.id))
