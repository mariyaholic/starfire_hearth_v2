class_name Stability
extends RefCounted
## Colony stability (§5.4). It is recomputed every turn from its sources (DESIGN_LOG 73), so the
## breakdown is the whole story: base 50, jobs, buildings, techs, ordinances, the origin,
## legacies, traits, events, unemployment, homelessness, pollution, energy shortage and famine.

const BASE: int = 50
const UNEMPLOYED: int = -3
const HOMELESS: int = -8
const ENERGY_SHORT: int = -10
const FAMINE: int = -15
const UNREST_AT: int = 15
const AUTONOMY_AT: int = 5
## Turns of warning before a colony at AUTONOMY_AT or below declares autonomy.
const AUTONOMY_WARNING: int = 5


static func target(state: GameState, c: Colony, cr: Economy.ColonyReport) -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.stability", Breakdown.UNIT_POINTS, false, ColonyRules.name_args(state, c))
	b.link_to("mechanic:stability")
	b.base("source.stability_base", BASE)
	if cr.job_stability != 0:
		b.add("source.jobs_stability", cr.job_stability, {"count": cr.job_stability_jobs, "job_key": "job.clerk.name"}, null, "job:clerk")
	Modifiers.add_lines(b, cr.entries, "stability_add")
	for p: Dictionary in cr.pollution:
		b.add(str(p["source_key"]), int(p["value"]), p["args"], null, str(p["link"]))
	if cr.unemployed > 0:
		b.add("source.unemployed", UNEMPLOYED * cr.unemployed, {"count": cr.unemployed}, null, "mechanic:jobs")
	if cr.homeless > 0:
		b.add("source.homeless", HOMELESS * cr.homeless, {"count": cr.homeless}, null, "mechanic:housing")
	var e: Empire = state.empires.get(c.owner_id, null)
	if e != null and e.energy_short_turns > 0:
		b.add("source.energy_short", ENERGY_SHORT, {}, null, "mechanic:shortage")
	if c.famine_turns > 0:
		b.add("source.famine", FAMINE, {}, null, "mechanic:famine")
	b.cap_max(100, "source.stability_range")
	b.cap_min(0, "source.stability_range")
	return b.finish()


## Phase 9, for one colony: stores the new stability and advances the autonomy count. Returns
## true if the colony declares autonomy this turn.
static func update(state: GameState, c: Colony, cr: Economy.ColonyReport, r: TurnResult) -> bool:
	var before: int = c.stability
	var b: Breakdown = target(state, c, cr)
	c.stability = b.total
	var entry: WhyLog.Entry = r.why_log.record(WhyLog.KIND_CHANGE, state.turn, "colony", c.id, "breakdown.stability", before, c.stability, Breakdown.UNIT_POINTS, ColonyRules.name_args(state, c))
	for l: Breakdown.Line in b.visible_lines():
		WhyLog.cause(entry, l.source_key, l.value, l.source_args)
	var args: Dictionary = ColonyRules.name_args(state, c)
	args["stability"] = c.stability
	if c.stability <= AUTONOMY_AT:
		c.autonomy_turns += 1
		if c.autonomy_turns > AUTONOMY_WARNING:
			return true
		args["turns"] = AUTONOMY_WARNING - c.autonomy_turns + 1
		r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 95, "report.autonomy_warning", args)
			.with_severity(ReportItem.SEVERITY_CRITICAL).with_breakdown(b).focus("colony", c.id))
	else:
		c.autonomy_turns = 0
		if c.stability <= UNREST_AT and before > UNREST_AT:
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 80, "report.unrest", args)
				.with_severity(ReportItem.SEVERITY_WARNING).with_breakdown(b).focus("colony", c.id))
		elif before - c.stability >= 10:
			args["from"] = before
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 55, "report.stability_fell", args)
				.with_severity(ReportItem.SEVERITY_WARNING).with_breakdown(b).focus("colony", c.id))
	return false


## The colony leaves its empire (§5.4). Its build queue is cancelled and refunded; a later event
## can bring it back. Losing the capital this way loses the scenario (phase 13).
static func declare_autonomy(state: GameState, c: Colony, r: TurnResult) -> void:
	var empire_id: String = c.owner_id
	for item: BuildItem in c.queue.duplicate():
		Construction.cancel(state, c, item.id)
	var e: Empire = state.empires[empire_id]
	e.stock["minerals"] = e.stock_of("minerals") + c.governor_funds
	c.governor_funds = 0
	c.governor_on = false
	c.autonomous_from = empire_id
	c.owner_id = ""
	c.autonomy_turns = 0
	var planet: Planet = state.planets[c.planet_id]
	var sys: StarSystem = state.systems[planet.system_id]
	var still_owned: bool = false
	for pid: String in sys.planet_ids:
		var other: Planet = state.planets[pid]
		if not other.colony_id.is_empty() and state.colonies[other.colony_id].owner_id == empire_id:
			still_owned = true
	if not still_owned:
		sys.owner_id = ""
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 99, "report.autonomy", ColonyRules.name_args(state, c))
		.with_severity(ReportItem.SEVERITY_CRITICAL).focus("colony", c.id))
