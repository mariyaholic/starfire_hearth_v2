class_name Objectives
extends RefCounted
## Scenario objectives, victory and loss (§5.12, §10.2). Objectives are data in the scenario file;
## each type below is a closed check with a readable progress count. Once done, an objective
## stays done.

const TYPES: Array[String] = ["colonies_developed", "outposts", "stability_streak", "flag", "total_pops", "techs", "never_flag"]
const LOSS_TYPES: Array[String] = ["capital_pops_zero", "capital_autonomy"]


## One objective's state for the UI and telemetry.
class Status:
	extends RefCounted
	var id: String = ""
	var required: bool = true
	var text_key: String = ""
	var progress: int = 0
	var target: int = 1
	var done: bool = false
	## A "never" objective that can no longer be met.
	var failed: bool = false


static func scenario(state: GameState) -> Dictionary:
	return Content.db().scenarios.get(state.scenario_id, {})


static func definitions(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var objs: Dictionary = DictIO.dict_of(scenario(state), "objectives")
	for group: String in ["required", "optional"]:
		for v: Variant in DictIO.arr_of(objs, group):
			var d: Dictionary = (v as Dictionary).duplicate()
			d["required"] = group == "required"
			out.append(d)
	return out


static func statuses(state: GameState) -> Array[Status]:
	var out: Array[Status] = []
	for d: Dictionary in definitions(state):
		out.append(status(state, d))
	return out


static func status(state: GameState, d: Dictionary) -> Status:
	var s: Status = Status.new()
	s.id = DictIO.str_of(d, "id")
	s.required = DictIO.bool_of(d, "required")
	s.text_key = DictIO.str_of(d, "text_key")
	var e: Empire = state.player()
	match DictIO.str_of(d, "type"):
		"colonies_developed":
			s.target = DictIO.int_of(d, "count", 1)
			for c: Colony in ColonyRules.settled(state, e.id):
				var sys: String = DictIO.str_of(d, "system")
				if (sys.is_empty() or state.planets[c.planet_id].system_id == sys) and ColonyRules.is_developed(c):
					s.progress += 1
		"outposts":
			s.target = DictIO.int_of(d, "count", 1)
			s.progress = ColonyRules.outposts(state, e.id).size()
		"stability_streak":
			s.target = DictIO.int_of(d, "turns", 10)
			s.progress = state.objective_progress.get(s.id, 0)
		"flag":
			s.progress = 1 if state.flags.has(DictIO.str_of(d, "flag")) or e.flags.has(DictIO.str_of(d, "flag")) else 0
		"total_pops":
			s.target = DictIO.int_of(d, "count", 1)
			for c: Colony in ColonyRules.settled(state, e.id):
				s.progress += c.pops
		"techs":
			s.target = DictIO.int_of(d, "count", 1)
			s.progress = e.techs.size()
		"never_flag":
			var flag: String = DictIO.str_of(d, "flag")
			s.failed = state.flags.has(flag) or e.flags.has(flag)
			s.progress = 0 if s.failed else 1
	s.progress = mini(s.progress, s.target)
	s.done = state.objectives_done.has(s.id)
	return s


## Phase 13.
static func update(state: GameState, r: TurnResult) -> void:
	if state.is_over() or state.player() == null:
		return
	var e: Empire = state.player()
	for d: Dictionary in definitions(state):
		var id: String = DictIO.str_of(d, "id")
		if DictIO.str_of(d, "type") == "stability_streak":
			_advance_streak(state, e, d)
		if state.objectives_done.has(id) or DictIO.str_of(d, "type") == "never_flag":
			continue
		var s: Status = status(state, d)
		if s.progress >= s.target:
			state.objectives_done[id] = state.turn
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_STORY, 88, "report.objective_done", {"objective_key": s.text_key})
				.with_severity(ReportItem.SEVERITY_GOOD).focus("objective", id))
	var reason: String = _loss(state, e)
	if not reason.is_empty():
		state.outcome = GameState.OUTCOME_LOST
		state.outcome_turn = state.turn
		state.outcome_reason = reason
		r.report_items.append(ReportItem.make(ReportItem.CATEGORY_STORY, 100, "report.scenario_lost", {"reason_key": reason})
			.with_severity(ReportItem.SEVERITY_CRITICAL))
		return
	for d: Dictionary in definitions(state):
		if DictIO.bool_of(d, "required") and not state.objectives_done.has(DictIO.str_of(d, "id")):
			return
	# Every required objective is done: "never" objectives that held count as done now.
	for d: Dictionary in definitions(state):
		if DictIO.str_of(d, "type") == "never_flag" and not status(state, d).failed:
			state.objectives_done[DictIO.str_of(d, "id")] = state.turn
	state.outcome = GameState.OUTCOME_WON
	state.outcome_turn = state.turn
	state.outcome_reason = "outcome.all_objectives"
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_STORY, 100, "report.scenario_won", {})
		.with_severity(ReportItem.SEVERITY_GOOD))


static func _advance_streak(state: GameState, e: Empire, d: Dictionary) -> void:
	var id: String = DictIO.str_of(d, "id")
	if state.objectives_done.has(id):
		return
	var colonies: Array[Colony] = ColonyRules.settled(state, e.id)
	var ok: bool = colonies.size() >= DictIO.int_of(d, "min_colonies", 1)
	for c: Colony in colonies:
		if c.stability < DictIO.int_of(d, "min", 40):
			ok = false
	state.objective_progress[id] = state.objective_progress.get(id, 0) + 1 if ok else 0


## The loss reason key, or "" while the scenario is not lost.
static func _loss(state: GameState, e: Empire) -> String:
	for v: Variant in DictIO.arr_of(scenario(state), "loss"):
		var rule: Dictionary = v
		match DictIO.str_of(rule, "type"):
			"capital_pops_zero":
				var cap: Colony = state.colonies.get(e.capital_id, null)
				if cap == null or cap.pops <= 0:
					return "outcome.capital_empty"
			"capital_autonomy":
				var cap2: Colony = state.colonies.get(e.capital_id, null)
				if cap2 != null and cap2.autonomous_from == e.id:
					return "outcome.capital_autonomy"
	return ""
