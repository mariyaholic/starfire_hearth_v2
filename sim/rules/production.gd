class_name Production
extends RefCounted
## Phase 3: applies an empire's net to its stocks. Stocks never go below zero (DESIGN_LOG 54):
## an energy shortfall leaves the grid short, which costs stability on every colony; running out
## of food starts famine (phase 4). Anything above a cap is lost (§5.3).

## Warn this many turns before a stock runs out or fills up.
const WARN_TURNS: int = 2
const FOOD_WARN_TURNS: int = 3


static func apply(state: GameState, e: Empire, er: Economy.EmpireReport, r: TurnResult) -> void:
	var db: ContentDb = Content.db()
	var short_energy: bool = false
	for res: String in Economy.STOCKED:
		var net: int = er.net_of(res)
		var cap: int = er.cap_of(res)
		var after: int = e.stock_of(res) + net
		var name_key: String = DictIO.str_of(db.record("resources", res), "name_key")
		if after < 0:
			if res == "energy":
				short_energy = true
			if res == "food" and not e.flags.has("food_ran_out"):
				e.flags["food_ran_out"] = state.turn
			if e.is_player:
				r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 92, "report.stock_empty", {"resource_key": name_key})
					.with_severity(ReportItem.SEVERITY_CRITICAL).with_breakdown(er.net[res]).focus("empire", e.id))
			after = 0
		if cap >= 0 and after > cap:
			if e.is_player and net > 0:
				r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 30, "report.overflow", {"resource_key": name_key, "lost_c": after - cap})
					.with_severity(ReportItem.SEVERITY_WARNING).with_breakdown(er.caps[res]).focus("empire", e.id))
			after = cap
		e.stock[res] = after
		if e.is_player:
			_warn_ahead(e, er, res, name_key, r)
	e.energy_short_turns = e.energy_short_turns + 1 if short_energy else 0
	for cid: String in DictIO.sorted_keys(er.governor_savings):
		if state.colonies.has(cid):
			state.colonies[cid].governor_funds += er.governor_savings[cid]


static func _warn_ahead(e: Empire, er: Economy.EmpireReport, res: String, name_key: String, r: TurnResult) -> void:
	var net: int = er.net_of(res)
	var stock: int = e.stock_of(res)
	if net < 0 and stock > 0:
		var turns: int = Economy.turns_until(stock, net, -1)
		var limit: int = FOOD_WARN_TURNS if res == "food" else WARN_TURNS
		if turns <= limit:
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 75, "report.will_run_out", {"resource_key": name_key, "turns": maxi(1, turns)})
				.with_severity(ReportItem.SEVERITY_WARNING).with_breakdown(er.net[res]).focus("empire", e.id))
	elif net > 0:
		var cap: int = er.cap_of(res)
		if cap >= 0 and stock < cap:
			var to_full: int = Economy.turns_until(stock, net, cap)
			if to_full >= 1 and to_full <= WARN_TURNS:
				r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 28, "report.will_overflow", {"resource_key": name_key, "turns": to_full})
					.with_severity(ReportItem.SEVERITY_INFO).with_breakdown(er.caps[res]).focus("empire", e.id))
