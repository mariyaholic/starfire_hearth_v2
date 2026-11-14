class_name Research
extends RefCounted
## Research (§5.5): three branches in parallel, each with a hand of up to 3 cards. Progress is
## stored per branch and carries over (DESIGN_LOG 70). When a tech completes, the two cards not
## picked stay and one new card is drawn; story techs are always offered once their
## prerequisites are met. Draws are seeded on the RESEARCH stream and favour lower tiers and techs
## that build on ones already owned.

## Negative ETA results distinguish absent selections, no income, and invalid input.
const ETA_NO_CARD: int = -1
const ETA_NO_INCOME: int = -2
const ETA_INVALID: int = -3

const HAND_SIZE: int = 3
const TIER_COST: Dictionary[int, int] = {1: 5500, 2: 15000, 3: 45000, 4: 100000}
const COST_PER_COLONY_BP: int = 500
const CATCH_UP_BP: int = -1500
const REROLL_COST: int = 2500
const TIER_WEIGHT: Dictionary[int, int] = {1: 6, 2: 5, 3: 3, 4: 2}
const PREREQ_WEIGHT: int = 2


static func cost(state: GameState, e: Empire, tech_id: String) -> Breakdown:
	var tech: Dictionary = Content.db().record("techs", tech_id)
	var tier: int = DictIO.int_of(tech, "tier", 1)
	var b: Breakdown = Breakdown.make("breakdown.research_cost", Breakdown.UNIT_CENTI, false, {"tech_key": DictIO.str_of(tech, "name_key")})
	b.link_to("mechanic:research")
	b.base("source.tech_tier", TIER_COST.get(tier, 8000), {"tier": tier})
	var colonies: int = ColonyRules.settled(state, e.id).size()
	if colonies > 1:
		b.mult("source.colony_count", COST_PER_COLONY_BP * (colonies - 1), {"count": colonies})
	return b.finish()


## Points carried in this branch, including when no card is selected.
static func stored_progress(state: GameState, empire_id: String, branch: String) -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.research_bank", Breakdown.UNIT_CENTI, false, {"branch_key": Names.branch(branch)})
	b.link_to("mechanic:research")
	var points: int = 0
	if state.empires.has(empire_id) and Empire.BRANCHES.has(branch) and state.empires[empire_id].research.has(branch):
		points = state.empires[empire_id].research[branch].progress
	b.base("source.research_bank", points)
	return b.finish()


## Whether the currently selected, valid card is already fully funded by stored points.
static func card_funded(state: GameState, empire_id: String, branch: String) -> bool:
	if not state.empires.has(empire_id) or not Empire.BRANCHES.has(branch):
		return false
	var e: Empire = state.empires[empire_id]
	if not e.research.has(branch):
		return false
	var rb: ResearchBranch = e.research[branch]
	var tech: Dictionary = Content.db().record("techs", rb.card)
	if rb.card.is_empty() or tech.is_empty() or DictIO.str_of(tech, "branch") != branch or not rb.hand.has(rb.card):
		return false
	return rb.progress >= cost(state, e, rb.card).total


## Current-rate estimate. A funded card completes during the next research phase even if the
## branch earns nothing; income changes in later turns can change a longer estimate.
static func turns_remaining(state: GameState, empire_id: String, branch: String) -> int:
	if not state.empires.has(empire_id) or not Empire.BRANCHES.has(branch):
		return ETA_INVALID
	var e: Empire = state.empires[empire_id]
	if not e.research.has(branch):
		return ETA_NO_CARD
	var rb: ResearchBranch = e.research[branch]
	if rb.card.is_empty():
		return ETA_NO_CARD
	var tech: Dictionary = Content.db().record("techs", rb.card)
	if tech.is_empty() or DictIO.str_of(tech, "branch") != branch or not rb.hand.has(rb.card):
		return ETA_INVALID
	var remaining: int = cost(state, e, rb.card).total - rb.progress
	if remaining <= 0:
		return 1
	var er: Economy.EmpireReport = Economy.empire(state, empire_id)
	var rate: int = maxi(0, er.research[branch].total) if er.research.has(branch) else 0
	if rate == 0:
		return ETA_NO_INCOME
	return maxi(1, Fx.div_ceil(remaining, rate))


## Techs of a branch that could be offered now: prerequisites met, not owned, allowed here.
static func available(state: GameState, e: Empire, branch: String) -> Array[String]:
	var db: ContentDb = Content.db()
	var out: Array[String] = []
	var no_military: bool = DictIO.bool_of(DictIO.dict_of(db.scenarios.get(state.scenario_id, {}), "tech_pool"), "exclude_military")
	for tid: String in db.ids("techs"):
		var t: Dictionary = db.record("techs", tid)
		if DictIO.str_of(t, "branch") != branch or e.has_tech(tid):
			continue
		if no_military and DictIO.bool_of(t, "military"):
			continue
		var ok: bool = true
		for p: String in DictIO.str_arr(t, "prereqs"):
			if not e.has_tech(p):
				ok = false
				break
		if ok:
			out.append(tid)
	return out


## Fills the hand up to HAND_SIZE: techs that are always offered first (story techs, and any the
## scenario's objectives need; DESIGN_LOG 79), then a seeded weighted draw. Cards in `exclude`
## are drawn only if nothing else is left.
static func refill(state: GameState, e: Empire, branch: String, exclude: Array[String] = []) -> void:
	var db: ContentDb = Content.db()
	var rb: ResearchBranch = e.branch(branch)
	var pool: Array[String] = []
	for tid: String in available(state, e, branch):
		if not rb.hand.has(tid):
			pool.append(tid)
	for tid: String in pool.duplicate():
		if rb.hand.size() >= HAND_SIZE:
			break
		if always_offered(state, tid):
			rb.hand.append(tid)
			pool.erase(tid)
	var fresh: Array[String] = []
	var used: Array[String] = []
	for tid: String in pool:
		if exclude.has(tid):
			used.append(tid)
		else:
			fresh.append(tid)
	var rng: RngStream = Rng.stream(state.game_seed, state.turn, Rng.RESEARCH, Rng.salt_of("%s:%s:%d" % [e.id, branch, rb.draws]))
	rb.draws += 1
	for candidates: Array[String] in [fresh, used]:
		while rb.hand.size() < HAND_SIZE and not candidates.is_empty():
			var weights: Array[int] = []
			for tid: String in candidates:
				weights.append(draw_weight(db.record("techs", tid)))
			var pick: int = rng.weighted(weights)
			rb.hand.append(candidates[pick])
			candidates.remove_at(pick)


## Story techs, and techs the scenario lists in tech_pool.always_offer.
static func always_offered(state: GameState, tech_id: String) -> bool:
	if DictIO.bool_of(Content.db().record("techs", tech_id), "story"):
		return true
	var pool: Dictionary = DictIO.dict_of(Content.db().scenarios.get(state.scenario_id, {}), "tech_pool")
	return DictIO.str_arr(pool, "always_offer").has(tech_id)


static func draw_weight(tech: Dictionary) -> int:
	return TIER_WEIGHT.get(DictIO.int_of(tech, "tier", 1), 1) + PREREQ_WEIGHT * DictIO.str_arr(tech, "prereqs").size()


## A new hand for the reroll: the picked card and story cards stay, the rest are replaced.
static func reroll(state: GameState, e: Empire, branch: String) -> void:
	var rb: ResearchBranch = e.branch(branch)
	var old: Array[String] = rb.hand.duplicate()
	var keep: Array[String] = []
	for tid: String in rb.hand:
		if tid == rb.card or always_offered(state, tid):
			keep.append(tid)
	rb.hand = keep
	refill(state, e, branch, old)


## Gives a tech and applies its one-shot effects (flags, decoding).
static func grant(state: GameState, e: Empire, tech_id: String) -> void:
	if e.has_tech(tech_id):
		return
	e.techs.append(tech_id)
	e.tech_turns[tech_id] = state.turn
	for fx: Variant in DictIO.arr_of(Content.db().record("techs", tech_id), "effects"):
		var d: Dictionary = fx
		match DictIO.str_of(d, "key"):
			"set_flag":
				e.flags[DictIO.str_of(d, "target")] = state.turn
			"clear_flag":
				e.flags.erase(DictIO.str_of(d, "target"))
			"decode_progress_add":
				e.decode_progress += DictIO.int_of(d, "value")


## Phase 5 for one empire.
static func update(state: GameState, e: Empire, er: Economy.EmpireReport, r: TurnResult) -> void:
	var db: ContentDb = Content.db()
	for branch: String in Empire.BRANCHES:
		var rb: ResearchBranch = e.branch(branch)
		rb.progress += maxi(0, er.research[branch].total) if er.research.has(branch) else 0
		if not rb.card.is_empty():
			var c: Breakdown = cost(state, e, rb.card)
			if rb.progress >= c.total:
				rb.progress -= c.total
				var done: String = rb.card
				grant(state, e, done)
				rb.hand.erase(done)
				rb.card = ""
				refill(state, e, branch)
				var tech: Dictionary = db.record("techs", done)
				r.report_items.append(ReportItem.make(ReportItem.CATEGORY_RESEARCH, 60, "report.tech_done",
					{"tech_key": DictIO.str_of(tech, "name_key"), "branch_key": Names.branch(branch)})
					.with_severity(ReportItem.SEVERITY_GOOD).focus("tech", done))
		if rb.hand.size() < HAND_SIZE:
			refill(state, e, branch)
	# Decoding needs the Archive of Sol, which only the Sealed Order grants.
	if er.decode.total > 0:
		e.decode_progress += er.decode.total
