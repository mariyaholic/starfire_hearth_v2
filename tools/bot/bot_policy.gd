class_name BotPolicy
extends RefCounted
## Bot players for headless playthroughs (§13.7). A policy reads the start-of-turn state and gives
## orders through the same commands and validation a human uses.
##
## - balanced: a competent player. Meets needs with the advisor's best build, surveys, founds
##   colonies and an outpost, picks research that serves the objectives, uses ordinances, turns
##   governors on for new colonies, and answers events by expected value.
## - economy: the same, but it values output over stability and prefers production techs.
## - turtle: stability first; it expands late and builds parks and halls early.
## - random-legal: uniformly random legal orders (a sanity floor). It still answers events,
##   at random, because a pending event must be answered.
## - military: arrives with fleets in M2; until then it plays like balanced.

const POLICIES: Array[String] = ["balanced", "economy", "military", "turtle", "random-legal"]
## Stream id for the bot's own choices; outside the game's stream ids (Rng.GEN .. Rng.FORECAST).
const BOT_STREAM: int = 99
## Research the objectives need, with the extra weight each gets (per policy tweaks below).
const OBJECTIVE_TECHS: Dictionary[String, int] = {
	"habitat_domes": 160, "frontier_medicine": 140, "wake_theory": 120, "sensor_arrays": 110,
	"colonial_administration": 40, "advanced_districts": 40, "civic_charters": 35,
	"research_network": 30, "cultural_archive": 30,
}


class Decision:
	extends RefCounted
	var commands: Array[Command] = []
	## Legal non-trivial orders the bot could have given this turn.
	var legal: int = 0
	## Legal orders that would change an outcome (the "no dead turns" gate counts these).
	var meaningful: int = 0


static func is_known(policy: String) -> bool:
	return POLICIES.has(policy)


static func decide(policy: String, state: GameState, empire_id: String, bot_seed: int) -> Decision:
	var d: Decision = Decision.new()
	var legal: Array[Command] = legal_commands(state, empire_id)
	d.legal = legal.size()
	d.meaningful = legal.size()
	var queue: CommandQueue = CommandQueue.new(state)
	if policy == "random-legal":
		_random(queue, empire_id, bot_seed, legal)
	else:
		_planned(policy, queue, empire_id)
	d.commands = queue.commands()
	return d


# --- Legal orders ----------------------------------------------------------------------------

## A representative set of legal, non-trivial orders: every build type on one free slot, every
## upgrade, ship, research card, reroll, ordinance, ship task and event choice.
static func legal_commands(state: GameState, empire_id: String) -> Array[Command]:
	var db: ContentDb = Content.db()
	var out: Array[Command] = []
	var e: Empire = state.empires[empire_id]
	for c: Colony in ColonyRules.settled(state, empire_id):
		var free: Array[int] = ColonyRules.free_slots(c, state.planets[c.planet_id])
		if not free.is_empty():
			for did: String in db.ids("districts"):
				var branch: String = Advisor.research_branch(state, e) if DictIO.bool_of(db.record("districts", did), "branch_choice") else ""
				out.append(PlaceDistrictCommand.create(empire_id, c.id, free[0], did, branch))
			for bid: String in db.ids("buildings"):
				out.append(BuildBuildingCommand.create(empire_id, c.id, free[0], bid))
		for pd: Colony.PlacedDistrict in c.districts:
			out.append(UpgradeDistrictCommand.create(empire_id, c.id, pd.slot))
		for hid: String in db.ids("hulls"):
			out.append(BuildShipCommand.create(empire_id, c.id, hid))
	for b: String in Empire.BRANCHES:
		for tid: String in e.branch(b).hand:
			out.append(PickResearchCommand.create(empire_id, b, tid))
		out.append(RerollResearchCommand.create(empire_id, b))
	for oid: String in db.ids("edicts"):
		out.append(ActivateOrdinanceCommand.create(empire_id, oid))
	for sh: Ship in state.ships_of(empire_id):
		if sh.is_busy():
			continue
		var sys: String = Ships.system_of(state, sh)
		for pid: String in state.systems[sys].planet_ids:
			match Ships.role(sh):
				Ships.ROLE_SURVEY:
					out.append(SurveyCommand.create(empire_id, sh.id, pid))
				Ships.ROLE_CONSTRUCTION:
					for kind: String in ColonyRules.outpost_kinds(state.planets[pid]):
						out.append(BuildOutpostCommand.create(empire_id, sh.id, pid, kind))
				Ships.ROLE_COLONY:
					out.append(ColoniseCommand.create(empire_id, sh.id, pid))
	for ev: EventInstance in Events.pending_for(state, empire_id):
		for i in DictIO.arr_of(Events.step_of(ev.chain, ev.step), "choices").size():
			out.append(ChooseEventCommand.create(empire_id, ev.id, i))
	var valid: Array[Command] = []
	for cmd: Command in out:
		if cmd.validate(state).ok:
			valid.append(cmd)
	return valid


# --- Random ----------------------------------------------------------------------------------

static func _random(queue: CommandQueue, empire_id: String, bot_seed: int, legal: Array[Command]) -> void:
	var state: GameState = queue.preview()
	var rng: RngStream = Rng.stream(bot_seed, state.turn, BOT_STREAM, Rng.salt_of("random-legal"))
	for ev: EventInstance in Events.pending_for(state, empire_id):
		var n: int = DictIO.arr_of(Events.step_of(ev.chain, ev.step), "choices").size()
		var order: Array[int] = []
		for i in n:
			order.append(i)
		rng.shuffle(order)
		for i: int in order:
			if queue.submit(ChooseEventCommand.create(empire_id, ev.id, i)).ok:
				break
	var picks: int = rng.range(0, 3)
	for _i in picks:
		if legal.is_empty():
			break
		var cmd: Command = legal[rng.range(0, legal.size() - 1)]
		if cmd is ChooseEventCommand:
			continue
		queue.submit(cmd)


# --- Planned policies ------------------------------------------------------------------------

static func _planned(policy: String, queue: CommandQueue, empire_id: String) -> void:
	_answer_events(policy, queue, empire_id)
	_pick_research(policy, queue, empire_id)
	_market(policy, queue, empire_id)
	_ship_tasks(policy, queue, empire_id)
	_colony_ship(policy, queue, empire_id)
	_governors(policy, queue, empire_id)
	_builds(policy, queue, empire_id)
	_ordinances(policy, queue, empire_id)


static func _stability_weight(policy: String) -> int:
	match policy:
		"turtle":
			return 25000
		"economy":
			return 5000
	return 10000


static func _answer_events(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var state: GameState = queue.preview()
	var e: Empire = state.empires[empire_id]
	for ev: EventInstance in Events.pending_for(state, empire_id):
		var n: int = DictIO.arr_of(Events.step_of(ev.chain, ev.step), "choices").size()
		var best: int = -1
		var best_v: int = -(1 << 30)
		for i in n:
			if not Events.can_choose(queue.preview(), empire_id, ev.id, i).ok:
				continue
			var v: int = Advisor.choice_value(queue.preview(), e, ev, i, _stability_weight(policy))
			if v > best_v:
				best_v = v
				best = i
		if best >= 0:
			queue.submit(ChooseEventCommand.create(empire_id, ev.id, best))


static func _pick_research(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var db: ContentDb = Content.db()
	for b: String in Empire.BRANCHES:
		var state: GameState = queue.preview()
		var e: Empire = state.empires[empire_id]
		var rb: ResearchBranch = e.branch(b)
		if not rb.card.is_empty() or rb.hand.is_empty():
			continue
		var best: String = ""
		var best_v: int = -(1 << 30)
		for tid: String in rb.hand:
			var v: int = tech_value(policy, state, e, db.record("techs", tid), tid)
			if v > best_v:
				best_v = v
				best = tid
		var fishing: bool = false
		for goal: String in Advisor.OBJECTIVE_TECH_BRANCH.keys():
			if Advisor.OBJECTIVE_TECH_BRANCH[goal] == b and not e.has_tech(goal) and not rb.hand.has(goal) and Research.available(state, e, b).has(goal):
				fishing = true
		if (fishing or best_v < 20) and e.stock_of("influence") >= Research.REROLL_COST + 2000 and policy != "turtle":
			if queue.submit(RerollResearchCommand.create(empire_id, b)).ok:
				continue
		queue.submit(PickResearchCommand.create(empire_id, b, best))


## A card's value for a policy: what its effects do for the economy, plus the objective bonus,
## per unit of cost.
static func tech_value(policy: String, state: GameState, e: Empire, tech: Dictionary, tid: String) -> int:
	var v: int = 0
	for fx: Variant in DictIO.arr_of(tech, "effects"):
		var key: String = DictIO.str_of(fx, "key")
		var val: int = DictIO.int_of(fx, "value")
		if key.begins_with("resource_output_bp:") or key.begins_with("research_bp:"):
			v += Fx.div_floor(val, 50) * (2 if policy == "economy" else 1)
		elif key == "stability_add":
			v += val * (12 if policy == "turtle" else 6)
		elif key == "growth_bp":
			v += Fx.div_floor(val, 80)
		elif key == "edict_slots_add":
			v += 25
	for bid: String in Content.db().ids("buildings"):
		if DictIO.str_of(Content.db().record("buildings", bid), "unlock_tech") == tid and not Advisor.NOT_YET_USEFUL.has(bid):
			v += 25
	var cost: int = Research.cost(state, e, tid).total
	# What the objectives need is worth its price whatever the price.
	return Fx.div_floor(v * 10000, maxi(1, cost)) + OBJECTIVE_TECHS.get(tid, 0) * 10


static func _ship_tasks(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var state: GameState = queue.preview()
	for sh: Ship in state.ships_of(empire_id):
		state = queue.preview()
		if not state.ships.has(sh.id) or state.ships[sh.id].is_busy():
			continue
		var sys: StarSystem = state.systems[Ships.system_of(state, sh)]
		match Ships.role(sh):
			Ships.ROLE_SURVEY:
				for pid: String in _survey_order(state, sys):
					if queue.submit(SurveyCommand.create(empire_id, sh.id, pid)).ok:
						break
			Ships.ROLE_CONSTRUCTION:
				if policy == "turtle" and state.turn < 30:
					continue
				var e: Empire = state.empires[empire_id]
				var want: int = 1 if policy == "turtle" else 2
				if ColonyRules.outposts(state, empire_id).size() >= want:
					continue
				if e.stock_of("influence") < Ships.outpost_cost(state, e).total + 1000:
					continue
				for pid2: String in sys.planet_ids:
					var p: Planet = state.planets[pid2]
					var kinds: Array[String] = ColonyRules.outpost_kinds(p)
					if kinds.is_empty():
						continue
					var kind: String = kinds[0]
					if kinds.has("research") and policy != "economy":
						kind = "research"
					if queue.submit(BuildOutpostCommand.create(empire_id, sh.id, pid2, kind)).ok:
						break
			Ships.ROLE_COLONY:
				for pid3: String in _colony_targets(state, empire_id):
					if queue.submit(ColoniseCommand.create(empire_id, sh.id, pid3)).ok:
						break


## Planets worth surveying, best first: open worlds, dome worlds, then outpost bodies.
static func _survey_order(state: GameState, sys: StarSystem) -> Array[String]:
	var order: Array[String] = []
	for hab: String in [ColonyRules.HAB_OPEN, ColonyRules.HAB_DOMES, ColonyRules.HAB_OUTPOST, ColonyRules.HAB_ORBITAL]:
		for pid: String in sys.planet_ids:
			if ColonyRules.habitability(state.planets[pid]) == hab:
				order.append(pid)
	return order


## Surveyed, free, settleable planets, open worlds first.
static func _colony_targets(state: GameState, empire_id: String) -> Array[String]:
	var e: Empire = state.empires[empire_id]
	var out: Array[String] = []
	for hab: String in [ColonyRules.HAB_OPEN, ColonyRules.HAB_DOMES]:
		for pid: String in e.surveyed_planets:
			var p: Planet = state.planets[pid]
			if p.colony_id.is_empty() and ColonyRules.habitability(p) == hab and ColonyRules.is_settleable(p, e):
				var taken: bool = false
				for sh: Ship in state.ships_of(empire_id):
					if sh.task == Ship.TASK_COLONISE and sh.task_target == pid:
						taken = true
				if not taken:
					out.append(pid)
	return out


## Builds a Colony Ship when a surveyed target waits and none is on the way.
static func _colony_ship(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var state: GameState = queue.preview()
	if policy == "turtle" and ColonyRules.settled(state, empire_id).size() >= 2 and state.turn < 45:
		return
	if not Advisor.needs_colony_ship(state, state.empires[empire_id]):
		return
	if _colony_targets(state, empire_id).is_empty() and not _target_coming(state, empire_id):
		return
	for c: Colony in ColonyRules.settled(state, empire_id):
		if Construction.provides(c, "spaceport"):
			queue.submit(BuildShipCommand.create(empire_id, c.id, "colony_ship"))
			return


## A settleable planet is being surveyed, or a dome world waits for Habitat Domes.
static func _target_coming(state: GameState, empire_id: String) -> bool:
	for sh: Ship in state.ships_of(empire_id):
		if sh.task == Ship.TASK_SURVEY and ColonyRules.habitability(state.planets[sh.task_target]) == ColonyRules.HAB_OPEN:
			return true
	return false


## The balanced and turtle bots hand new colonies to a governor; economy plans them itself.
static func _governors(policy: String, queue: CommandQueue, empire_id: String) -> void:
	if policy == "economy":
		return
	var state: GameState = queue.preview()
	var e: Empire = state.empires[empire_id]
	for c: Colony in ColonyRules.settled(state, empire_id):
		if c.id == e.capital_id or c.governor_on:
			continue
		var focus: String = "stability" if policy == "turtle" else "balanced"
		queue.submit(SetGovernorCommand.create(empire_id, c.id, true, focus, 6000))


## Planned builds: the advisor's best option for each colony without a governor, while keeping
## a reserve for a Colony Ship that is about to be needed.
static func _builds(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var focus: String = {"economy": "industry", "turtle": "stability"}.get(policy, "balanced")
	for c: Colony in ColonyRules.settled(queue.preview(), empire_id):
		var state: GameState = queue.preview()
		var col: Colony = state.colonies[c.id]
		if col.governor_on or col.queue.size() >= 2:
			continue
		var e: Empire = state.empires[empire_id]
		var er: Economy.EmpireReport = Economy.empire(state, empire_id)
		var reserve: int = _reserve(state, e)
		var opts: Array[Advisor.Option] = Advisor.options(state, col, er, focus)
		if _save_for(opts, e, er, reserve):
			continue
		for o: Advisor.Option in opts:
			if o.value <= 0:
				break
			if e.stock_of("minerals") - o.cost.get("minerals", 0) < reserve:
				continue
			var cmd: Command = _option_command(empire_id, col.id, o)
			if cmd != null and queue.submit(cmd).ok:
				break


## True when the best option cannot be paid for yet but clearly beats everything affordable and
## a few turns of minerals income will cover it: then the bot saves up, as a player would.
static func _save_for(opts: Array[Advisor.Option], e: Empire, er: Economy.EmpireReport, reserve: int) -> bool:
	if opts.is_empty() or opts[0].value <= 0:
		return false
	var best: Advisor.Option = opts[0]
	var short: int = best.cost.get("minerals", 0) + reserve - e.stock_of("minerals")
	if short <= 0:
		return false
	var income: int = er.net_of("minerals")
	if income <= 0 or short > income * 6:
		return false
	for o: Advisor.Option in opts:
		if o.value > 0 and e.stock_of("minerals") - o.cost.get("minerals", 0) >= reserve:
			return best.value * 10 >= o.value * 14
	return true


## Minerals kept back for a Colony Ship when its metals are nearly there and a target waits.
static func _reserve(state: GameState, e: Empire) -> int:
	if not Advisor.needs_colony_ship(state, e):
		return 0
	if _colony_targets(state, e.id).is_empty():
		return 0
	if e.stock_of("alloys") < 3000:
		return 0
	return _colony_ship_need("minerals")


static func _option_command(empire_id: String, colony_id: String, o: Advisor.Option) -> Command:
	match o.kind:
		BuildItem.KIND_DISTRICT:
			return PlaceDistrictCommand.create(empire_id, colony_id, o.slot, o.def_id, o.branch)
		BuildItem.KIND_UPGRADE:
			return UpgradeDistrictCommand.create(empire_id, colony_id, o.slot)
		BuildItem.KIND_BUILDING:
			return BuildBuildingCommand.create(empire_id, colony_id, o.slot, o.def_id)
	return null


## Influence is worth spending: outposts come first (kept in reserve), then ordinances, then
## rerolls when it keeps piling up.
static func _ordinances(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var state: GameState = queue.preview()
	var e: Empire = state.empires[empire_id]
	var low: int = Advisor._lowest_stability(state, e)
	var energy_net: int = Economy.empire(state, empire_id).net_of("energy")
	var reserve: int = 0
	if ColonyRules.outposts(state, empire_id).size() < (1 if policy == "turtle" else 2):
		reserve = Ships.outpost_cost(state, e).total
	var wants: Array[String] = []
	if low < (75 if policy == "turtle" else 68):
		wants.append("festival")
	if energy_net > 300:
		wants.append("research_grants")
	if policy != "turtle" and low >= 62:
		wants.append("work_drive")
	for oid: String in wants:
		state = queue.preview()
		e = state.empires[empire_id]
		var cost: int = Ordinances.activation_cost(oid).get("influence", 0)
		if e.stock_of("influence") - cost < reserve:
			continue
		queue.submit(ActivateOrdinanceCommand.create(empire_id, oid))
	state = queue.preview()
	e = state.empires[empire_id]
	if e.stock_of("influence") - Research.REROLL_COST >= reserve + 6000:
		for b: String in Empire.BRANCHES:
			if queue.submit(RerollResearchCommand.create(empire_id, b)).ok:
				break


## Stock management: a stock above about seven turns of its gross income is surplus. Surplus
## food and metals are sold, surplus energy rushes the builds in progress and then buys what is
## short, all without touching what the next Colony Ship needs.
static func _market(policy: String, queue: CommandQueue, empire_id: String) -> void:
	var state: GameState = queue.preview()
	var e: Empire = state.empires[empire_id]
	var er: Economy.EmpireReport = Economy.empire(state, empire_id)
	var open: bool = Market.is_open(state, empire_id)
	var ship: bool = Advisor.needs_colony_ship(state, e)
	if open:
		for res: String in ["food", "alloys", "minerals"]:
			var keep: int = _target(er, res) + (_colony_ship_need(res) if ship else 0)
			var surplus: int = e.stock_of(res) - keep
			if surplus >= Market.LOT:
				queue.submit(TradeCommand.create(empire_id, res, mini(Market.MAX_LOTS, Fx.div_floor(surplus, Market.LOT)), false))
	# Rush builds in progress with surplus energy.
	for c: Colony in ColonyRules.settled(queue.preview(), empire_id):
		state = queue.preview()
		e = state.empires[empire_id]
		var col: Colony = state.colonies[c.id]
		if col.queue.is_empty():
			continue
		var cost: int = Construction.rush_cost(col.queue[0]).total
		if e.stock_of("energy") - cost >= _target(er, "energy"):
			queue.submit(RushBuildCommand.create(empire_id, col.id, col.queue[0].id))
	if not open:
		return
	state = queue.preview()
	e = state.empires[empire_id]
	var spare: int = e.stock_of("energy") - _target(er, "energy")
	if spare <= 0:
		return
	var buy: String = ""
	if ship and e.stock_of("alloys") < _colony_ship_need("alloys"):
		buy = "alloys"
	elif e.stock_of("minerals") < _target(er, "minerals"):
		buy = "minerals"
	elif ship and e.stock_of("food") < _colony_ship_need("food"):
		buy = "food"
	if buy.is_empty():
		return
	var lots: int = mini(Market.MAX_LOTS, Fx.div_floor(spare, Market.price(buy, Market.LOT, true)))
	if lots > 0:
		queue.submit(TradeCommand.create(empire_id, buy, lots, true))


## The stock worth keeping: about seven turns of gross income, at least 30.00, at most half the cap.
static func _target(er: Economy.EmpireReport, res: String) -> int:
	var g: int = BotRunner.gross_income(er, res)
	var t: int = maxi(3000, g * 7)
	var cap: int = er.cap_of(res)
	if cap > 0:
		t = mini(t, Fx.div_floor(cap, 2))
	return t


static func _colony_ship_need(res: String) -> int:
	return int(DictIO.dict_of(Content.db().record("hulls", "colony_ship"), "cost").get(res, 0))
