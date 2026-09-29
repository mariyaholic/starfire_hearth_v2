class_name GameModel
extends RefCounted
## What the game screen derives from a state: the top bar's numbers with their breakdowns, and the
## End Turn checklist. Pure functions of a state, so tests call them without a screen.


## The top bar for the player's empire (`er` is its economy report for the same state).
static func top_bar(state: GameState, er: Economy.EmpireReport) -> TopBar.Model:
	var db: ContentDb = Content.db()
	var e: Empire = state.player()
	var m: TopBar.Model = TopBar.Model.new()
	for rid: String in db.ids("resources"):
		var rec: Dictionary = db.record("resources", rid)
		var net: Breakdown = er.net[rid] if er.net.has(rid) else research_breakdown(er)
		m.resources[rid] = {
			"icon": DictIO.str_of(rec, "icon"), "color": DictIO.str_of(rec, "color"),
			"name_key": DictIO.str_of(rec, "name_key"),
			# Research has no stockpile: it flows into the current cards.
			"stock": -1 if rid == "research" else e.stock_of(rid),
			"net": net.total, "breakdown": net,
		}
		m.resource_order.append(rid)
	m.noise = e.noise
	var nb: Breakdown = Breakdown.make("breakdown.noise", Breakdown.UNIT_CENTI)
	nb.base("source.noise_last", e.noise)
	nb.note("note.noise_thresholds")
	m.noise_breakdown = nb.finish()
	m.turn = state.turn
	m.turn_breakdown = turn_breakdown(state.turn)
	return m


static func turn_breakdown(turn: int) -> Breakdown:
	var tb: Breakdown = Breakdown.make("breakdown.turn", Breakdown.UNIT_COUNT)
	tb.base("source.turns_played", turn)
	tb.note("note.calendar")
	return tb.finish()


## Research per turn, summed over the three branches.
static func research_breakdown(er: Economy.EmpireReport) -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "research", true, {"resource_key": "res.research.name"})
	for branch: String in Empire.BRANCHES:
		if er.research.has(branch):
			b.add("source.research_branch", er.research[branch].total, {"branch_key": Names.branch(branch)}, er.research[branch])
	return b.finish()


## What still wants an order before the turn ends, worst first: events waiting for an answer
## (these block End Turn), idle civilian ships, branches with no card, stores about to overflow.
static func end_turn_checks(state: GameState, er: Economy.EmpireReport) -> Array[ReportItem]:
	var db: ContentDb = Content.db()
	var e: Empire = state.player()
	var out: Array[ReportItem] = []
	for ev: EventInstance in Events.pending_for(state, e.id):
		var st: Dictionary = Events.step_of(ev.chain, ev.step)
		var it: ReportItem = ReportItem.make(ReportItem.CATEGORY_STORY, 100, "ui.endturn.event", {"title_key": DictIO.str_of(st, "title_key")})
		it.with_severity(ReportItem.SEVERITY_CRITICAL).focus("event", ev.id)
		it.blocks_end_turn = true
		out.append(it)
	for sh: Ship in state.ships_of(e.id):
		var hull: Dictionary = db.record("hulls", sh.hull)
		if sh.is_busy() or DictIO.str_of(hull, "class") != "civilian":
			continue
		var sys_id: String = Ships.system_of(state, sh)
		var args: Dictionary = {"ship_key": DictIO.str_of(hull, "name_key")}
		if state.systems.has(sys_id):
			args["system_key"] = state.systems[sys_id].name_key
		out.append(ReportItem.make(ReportItem.CATEGORY_FLEETS, 40, "ui.endturn.ship_idle", args).with_severity(ReportItem.SEVERITY_WARNING).focus("system", sys_id))
	for branch: String in Empire.BRANCHES:
		var rb: ResearchBranch = e.research.get(branch, null)
		if rb != null and rb.card.is_empty() and not rb.hand.is_empty():
			out.append(ReportItem.make(ReportItem.CATEGORY_RESEARCH, 50, "ui.endturn.research_empty", {"branch_key": Names.branch(branch)}).with_severity(ReportItem.SEVERITY_WARNING).focus("research", branch))
	for res: String in Economy.STOCKED:
		var cap: int = er.cap_of(res)
		var net: int = er.net_of(res)
		if cap <= 0 or net <= 0:
			continue
		var turns: int = Economy.turns_until(e.stock_of(res), net, cap)
		if turns >= 0 and turns <= 2:
			var rname: String = DictIO.str_of(db.record("resources", res), "name_key")
			out.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 60, "ui.endturn.overflow", {"resource_key": rname, "turns": turns}).with_severity(ReportItem.SEVERITY_WARNING).with_breakdown(er.net[res]))
	return ReportBuilder.ranked(out)


## The first report of a game: the scenario's name, then what wants orders.
static func opening_report(state: GameState, er: Economy.EmpireReport) -> Array[ReportItem]:
	var out: Array[ReportItem] = []
	var scenario: Dictionary = Content.db().scenarios.get(state.scenario_id, {})
	out.append(ReportItem.make(ReportItem.CATEGORY_STORY, 90, "ui.report.opening", {"scenario_key": DictIO.str_of(scenario, "name_key")}))
	out.append_array(end_turn_checks(state, er))
	return out


## The player's capital colony, or the first colony it has.
static func capital(state: GameState) -> Colony:
	var e: Empire = state.player()
	if state.colonies.has(e.capital_id):
		return state.colonies[e.capital_id]
	for c: Colony in state.colonies_of(e.id):
		return c
	return null


## The scenario's main track (§15.5), for when a story cue ends.
static func main_music(state: GameState) -> String:
	var music: Dictionary = DictIO.dict_of(Content.db().scenarios.get(state.scenario_id, {}), "music")
	return DictIO.str_of(music, "main", "mus_slowboat_1")
