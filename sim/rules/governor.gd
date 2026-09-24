class_name Governor
extends RefCounted
## Colony governors (§5.4). A governor queues one build at a time, chosen by the advisor for its
## focus, and pays its minerals from its own purse: each turn the production phase sets aside its
## share of the empire's minerals income (default 50%; DESIGN_LOG 71, 80). Other costs come from
## the empire's stock. It always shows its next plan with a one-line reason, and a vetoed plan
## is skipped for 10 turns. Turning a governor off returns its purse.

const VETO_TURNS: int = 10
## Funds stop growing at this many minerals, so an idle governor cannot hoard.
const FUNDS_CAP: int = 40000


## The governor's next build and why, or null when there is nothing worth building.
static func plan(state: GameState, c: Colony, er: Economy.EmpireReport) -> Advisor.Option:
	for o: Advisor.Option in Advisor.options(state, c, er, c.governor_focus):
		if is_vetoed(state, c, o.veto_key()):
			continue
		if o.value <= 0:
			return null
		return o
	return null


static func is_vetoed(state: GameState, c: Colony, key: String) -> bool:
	return c.governor_vetoes.has(key) and c.governor_vetoes[key] >= state.turn


## What the governor sets aside this turn (computed with the empire's economy).
static func allowance(c: Colony, er: Economy.EmpireReport) -> int:
	return er.governor_savings.get(c.id, 0)


## Phase 2, before construction advances: every governed colony with an empty queue starts its
## plan when its purse and the empire's stock allow.
static func run(state: GameState, e: Empire, r: TurnResult) -> void:
	var governed: Array[Colony] = []
	for c: Colony in state.colonies_of(e.id):
		if c.governor_on and not c.is_outpost():
			governed.append(c)
	if governed.is_empty():
		return
	var er: Economy.EmpireReport = Economy.empire(state, e.id)
	for c: Colony in governed:
		for key: String in DictIO.sorted_keys(c.governor_vetoes):
			if c.governor_vetoes[key] < state.turn:
				c.governor_vetoes.erase(key)
		if not c.queue.is_empty():
			continue
		var p: Advisor.Option = plan(state, c, er)
		if p == null:
			continue
		var minerals: int = p.cost.get("minerals", 0)
		var rest: Dictionary[String, int] = p.cost.duplicate()
		rest.erase("minerals")
		if c.governor_funds < minerals or not Construction.can_afford(e, rest):
			continue
		if not _still_valid_with_funds(state, c, p):
			continue
		Construction.enqueue(state, c, p.kind, p.def_id, p.slot, p.tier, p.branch, p.cost, true)
		if e.is_player:
			var args: Dictionary = ColonyRules.name_args(state, c)
			args["what_key"] = _name_key(p)
			args["reason_key"] = p.reason_key
			for k: Variant in p.reason_args.keys():
				args[k] = p.reason_args[k]
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 20, "report.governor_queued", args)
				.with_severity(ReportItem.SEVERITY_INFO).focus("colony", c.id))
		er = Economy.empire(state, e.id)


## The plan is still placeable (its minerals come from the purse, so only a shortage of them in
## the empire's stock is ignored).
static func _still_valid_with_funds(state: GameState, c: Colony, p: Advisor.Option) -> bool:
	var r: Result
	match p.kind:
		BuildItem.KIND_DISTRICT:
			r = Construction.can_place_district(state, c.owner_id, c.id, p.slot, p.def_id, p.branch)
		BuildItem.KIND_UPGRADE:
			r = Construction.can_upgrade(state, c.owner_id, c.id, p.slot)
		BuildItem.KIND_BUILDING:
			r = Construction.can_build_building(state, c.owner_id, c.id, p.slot, p.def_id)
		_:
			return false
	return r.ok or (r.reason_key == "error.build.cannot_afford" and str(r.args.get("resource_key", "")) == "res.minerals.name")


static func _name_key(p: Advisor.Option) -> String:
	var table: String = "buildings" if p.kind == BuildItem.KIND_BUILDING else "districts"
	return DictIO.str_of(Content.db().record(table, p.def_id), "name_key")
