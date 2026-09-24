class_name Population
extends RefCounted
## Growth, homelessness and famine (§5.4). Growth progress per turn is 10 + 2 per free home (at
## most 20), adjusted by habitability and growth bonuses, halved while settlers are homeless, and
## paused while food is running down. A new pop arrives at 100.

const GROWTH_BASE: int = 1000
const GROWTH_PER_FREE: int = 200
const GROWTH_MAX: int = 2000
const GROWTH_NEEDED: int = 10000
const HOMELESS_BP: int = -5000
## Famine takes one pop every this many turns.
const FAMINE_PERIOD: int = 3


## Growth progress per turn for a colony, given the empire's food net and stock.
static func growth(state: GameState, c: Colony, cr: Economy.ColonyReport, food_net: int, food_stock: int) -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.growth", Breakdown.UNIT_CENTI, true, ColonyRules.name_args(state, c))
	b.link_to("mechanic:growth")
	if c.is_outpost() or c.pops <= 0:
		return b.finish()
	var free: int = maxi(0, cr.free_housing)
	b.base("source.growth_base", mini(GROWTH_BASE + GROWTH_PER_FREE * free, GROWTH_MAX), {"free": free})
	var planet: Planet = state.planets[c.planet_id]
	var hab: int = ColonyRules.habitability_bp(planet)
	if hab != 10000:
		b.mult("source.habitability", hab - 10000, {"pct": Fx.div_floor(hab, 100)}, null, "mechanic:habitability")
	Modifiers.mult_lines(b, cr.entries, "growth_bp")
	if cr.homeless > 0:
		b.mult("source.homeless_growth", HOMELESS_BP, {"count": cr.homeless}, null, "mechanic:housing")
	if food_net < 0 or food_stock <= 0:
		b.cap_max(0, "source.growth_paused_food", {}, "mechanic:food")
	b.cap_min(0, "source.never_negative")
	return b.finish()


## Phase 4 for one colony: growth, then famine.
static func update(state: GameState, c: Colony, cr: Economy.ColonyReport, food_net: int, food_stock: int, r: TurnResult) -> void:
	if c.is_outpost():
		return
	var g: Breakdown = growth(state, c, cr, food_net, food_stock)
	c.growth += g.total
	while c.growth >= GROWTH_NEEDED:
		c.growth -= GROWTH_NEEDED
		c.pops += 1
		var args: Dictionary = ColonyRules.name_args(state, c)
		args["pops"] = c.pops
		r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 25, "report.new_pop", args)
			.with_severity(ReportItem.SEVERITY_GOOD).with_breakdown(g).focus("colony", c.id))
	if food_stock <= 0 and food_net < 0:
		c.famine_turns += 1
		var fargs: Dictionary = ColonyRules.name_args(state, c)
		if c.famine_turns % FAMINE_PERIOD == 0 and c.pops > 0:
			c.pops -= 1
			c.growth = 0
			fargs["pops"] = c.pops
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 98, "report.famine_loss", fargs)
				.with_severity(ReportItem.SEVERITY_CRITICAL).focus("colony", c.id))
		else:
			fargs["turns"] = FAMINE_PERIOD - c.famine_turns % FAMINE_PERIOD
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 90, "report.famine", fargs)
				.with_severity(ReportItem.SEVERITY_CRITICAL).focus("colony", c.id))
	else:
		c.famine_turns = 0
