class_name Construction
extends RefCounted
## Build queues (DESIGN_LOG 57): districts, district upgrades, buildings and ships. The cost is
## paid when an item is queued and refunded in full if it is cancelled. Only the first item of a
## colony's queue progresses. Demolishing is instant and refunds nothing.
##
## Every check returns a Result whose reason key says why an order is refused; commands, the
## governor, the bots and the planner all use the same checks.

const MAX_QUEUE: int = 5


# --- Costs ----------------------------------------------------------------------------------

static func district_cost(district_id: String) -> Dictionary[String, int]:
	return _res_map(DictIO.dict_of(Content.db().record("districts", district_id), "cost"))


static func upgrade_cost(district_id: String, tier: int) -> Dictionary[String, int]:
	var ddef: Dictionary = Content.db().record("districts", district_id)
	var mult: int = DictIO.int_of(Economy._tier_record(ddef, tier), "cost_mult_bp", 10000)
	var out: Dictionary[String, int] = {}
	var base: Dictionary[String, int] = district_cost(district_id)
	for res: String in DictIO.sorted_keys(base):
		out[res] = Fx.mul_bp(base[res], mult)
	return out


static func building_cost(building_id: String) -> Dictionary[String, int]:
	return _res_map(DictIO.dict_of(Content.db().record("buildings", building_id), "cost"))


## A hull's cost at a colony, after ship cost bonuses there (Low Gravity).
static func ship_cost(state: GameState, c: Colony, hull_id: String) -> Dictionary[String, int]:
	var base: Dictionary[String, int] = _res_map(DictIO.dict_of(Content.db().record("hulls", hull_id), "cost"))
	var bp: int = 0
	if c != null:
		bp = Modifiers.total(Modifiers.for_colony(state, c), "ship_cost_bp")
	var out: Dictionary[String, int] = {}
	for res: String in DictIO.sorted_keys(base):
		out[res] = base[res] + Fx.mul_bp(base[res], bp)
	return out


static func build_turns(kind: String, def_id: String) -> int:
	var db: ContentDb = Content.db()
	match kind:
		BuildItem.KIND_DISTRICT, BuildItem.KIND_UPGRADE:
			return maxi(1, DictIO.int_of(db.record("districts", def_id), "build_turns", 3))
		BuildItem.KIND_BUILDING:
			return maxi(1, DictIO.int_of(db.record("buildings", def_id), "build_turns", 3))
		BuildItem.KIND_SHIP:
			return maxi(1, DictIO.int_of(db.record("hulls", def_id), "build_turns", 3))
	return 1


static func can_afford(e: Empire, cost: Dictionary[String, int]) -> bool:
	for res: String in cost.keys():
		if e.stock_of(res) < cost[res]:
			return false
	return true


## The first resource the empire is short of, for the refusal message; "" when affordable.
static func short_of(e: Empire, cost: Dictionary[String, int]) -> String:
	for res: String in DictIO.sorted_keys(cost):
		if e.stock_of(res) < cost[res]:
			return res
	return ""


# --- Checks ---------------------------------------------------------------------------------

## A settled colony the empire owns, with room in its queue.
static func check_colony(state: GameState, empire_id: String, colony_id: String) -> Result:
	var failures: Array[Result] = []
	var c: Colony = Command.owned_colony(state, empire_id, colony_id, failures)
	if c == null:
		return failures[0]
	if c.is_outpost():
		return Result.fail("error.build.outpost")
	if c.queue.size() >= MAX_QUEUE:
		return Result.fail("error.build.queue_full", {"max": MAX_QUEUE})
	return Result.success()


static func can_place_district(state: GameState, empire_id: String, colony_id: String, slot: int, district_id: String, branch: String) -> Result:
	var r: Result = check_colony(state, empire_id, colony_id)
	if not r.ok:
		return r
	var db: ContentDb = Content.db()
	if not db.has("districts", district_id):
		return Result.fail("error.build.unknown")
	var c: Colony = state.colonies[colony_id]
	var planet: Planet = state.planets[c.planet_id]
	var slot_r: Result = _check_slot(c, planet, slot)
	if not slot_r.ok:
		return slot_r
	var ddef: Dictionary = db.record("districts", district_id)
	if DictIO.bool_of(ddef, "branch_choice"):
		if not Empire.BRANCHES.has(branch):
			return Result.fail("error.build.branch_needed")
	elif not branch.is_empty():
		return Result.fail("error.build.no_branch")
	return _check_cost(state.empires[empire_id], district_cost(district_id))


static func can_upgrade(state: GameState, empire_id: String, colony_id: String, slot: int) -> Result:
	var r: Result = check_colony(state, empire_id, colony_id)
	if not r.ok:
		return r
	var c: Colony = state.colonies[colony_id]
	var pd: Colony.PlacedDistrict = c.district_at(slot)
	if pd == null:
		return Result.fail("error.build.no_district")
	if c.queued_at(slot) != null:
		return Result.fail("error.build.already_upgrading")
	var ddef: Dictionary = Content.db().record("districts", pd.district_id)
	var next_tier: int = pd.tier + 1
	var tier: Dictionary = Economy._tier_record(ddef, next_tier)
	if tier.is_empty():
		return Result.fail("error.build.max_tier")
	var tech: String = DictIO.str_of(tier, "requires_tech")
	var e: Empire = state.empires[empire_id]
	if not tech.is_empty() and not e.has_tech(tech):
		return Result.fail("error.build.needs_tech", {"tech_key": DictIO.str_of(Content.db().record("techs", tech), "name_key")})
	var stage: String = ColonyRules.stage_for_tier(next_tier)
	if not ColonyRules.stage_reached(c, stage):
		return Result.fail("error.build.needs_stage", {"stage_key": Names.stage(stage), "tier": next_tier})
	return _check_cost(e, upgrade_cost(pd.district_id, next_tier))


static func can_build_building(state: GameState, empire_id: String, colony_id: String, slot: int, building_id: String) -> Result:
	var r: Result = check_colony(state, empire_id, colony_id)
	if not r.ok:
		return r
	var db: ContentDb = Content.db()
	if not db.has("buildings", building_id):
		return Result.fail("error.build.unknown")
	var bdef: Dictionary = db.record("buildings", building_id)
	if DictIO.bool_of(bdef, "story") or DictIO.bool_of(bdef, "landmark"):
		return Result.fail("error.build.story_only")
	var e: Empire = state.empires[empire_id]
	var tech: String = DictIO.str_of(bdef, "unlock_tech")
	if not tech.is_empty() and not e.has_tech(tech):
		return Result.fail("error.build.needs_tech", {"tech_key": DictIO.str_of(db.record("techs", tech), "name_key")})
	var c: Colony = state.colonies[colony_id]
	var planet: Planet = state.planets[c.planet_id]
	if DictIO.str_of(bdef, "requires") == "dome_world" and not ColonyRules.is_dome_world(planet):
		return Result.fail("error.build.needs_dome_world")
	match DictIO.str_of(bdef, "unique"):
		"colony":
			if c.has_building(building_id) or _queued_building(c, building_id):
				return Result.fail("error.build.unique_colony")
		"empire":
			for other: Colony in state.colonies_of(empire_id):
				if other.has_building(building_id) or _queued_building(other, building_id):
					return Result.fail("error.build.unique_empire")
	if ColonyRules.building_count(c) >= ColonyRules.building_cap(c):
		return Result.fail("error.build.building_cap", {"max": ColonyRules.building_cap(c)})
	var slot_r: Result = _check_slot(c, planet, slot)
	if not slot_r.ok:
		return slot_r
	return _check_cost(e, building_cost(building_id))


static func can_build_ship(state: GameState, empire_id: String, colony_id: String, hull_id: String) -> Result:
	var r: Result = check_colony(state, empire_id, colony_id)
	if not r.ok:
		return r
	var db: ContentDb = Content.db()
	if not db.has("hulls", hull_id):
		return Result.fail("error.build.unknown")
	var hdef: Dictionary = db.record("hulls", hull_id)
	if DictIO.str_of(hdef, "class") != "civilian":
		return Result.fail("error.ship.warships_later")
	var c: Colony = state.colonies[colony_id]
	if not provides(c, "spaceport"):
		return Result.fail("error.ship.needs_spaceport")
	var e: Empire = state.empires[empire_id]
	var tech: String = DictIO.str_of(hdef, "unlock_tech")
	if not tech.is_empty() and not e.has_tech(tech):
		return Result.fail("error.build.needs_tech", {"tech_key": DictIO.str_of(db.record("techs", tech), "name_key")})
	return _check_cost(e, ship_cost(state, c, hull_id))


static func can_demolish(state: GameState, empire_id: String, colony_id: String, slot: int) -> Result:
	var failures: Array[Result] = []
	var c: Colony = Command.owned_colony(state, empire_id, colony_id, failures)
	if c == null:
		return failures[0]
	var pb: Colony.PlacedBuilding = c.building_at(slot)
	if c.district_at(slot) == null and pb == null:
		return Result.fail("error.build.nothing_there")
	if pb != null and DictIO.bool_of(Content.db().record("buildings", pb.building_id), "story"):
		return Result.fail("error.build.story_only")
	if c.queued_at(slot) != null:
		return Result.fail("error.build.busy_slot")
	return Result.success()


static func can_cancel(state: GameState, empire_id: String, colony_id: String, item_id: String) -> Result:
	var failures: Array[Result] = []
	var c: Colony = Command.owned_colony(state, empire_id, colony_id, failures)
	if c == null:
		return failures[0]
	if _item_index(c, item_id) < 0:
		return Result.fail("error.build.not_queued")
	return Result.success()


static func can_move_up(state: GameState, empire_id: String, colony_id: String, item_id: String) -> Result:
	var r: Result = can_cancel(state, empire_id, colony_id, item_id)
	if not r.ok:
		return r
	if _item_index(state.colonies[colony_id], item_id) == 0:
		return Result.fail("error.build.already_first")
	return Result.success()


## What rushing the item in progress costs: its price per turn of work, valued in energy at the
## market's buying rates (energy counts as itself). Rushing takes one turn off, once a turn, and
## never finishes an item before the end of the turn (DESIGN_LOG 81).
static func rush_cost(item: BuildItem) -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.rush_cost", "energy", false)
	b.link_to("mechanic:rush")
	var value: int = 0
	for res: String in DictIO.sorted_keys(item.paid):
		var rate: int = int(Market.RATES[res][0]) if Market.RATES.has(res) else Fx.ONE
		value += Fx.div_floor(item.paid[res] * rate, Fx.ONE)
	b.base("source.rush_per_turn", Fx.div_ceil(value, maxi(1, item.total_turns)), {"turns": item.total_turns})
	return b.finish()


static func can_rush(state: GameState, empire_id: String, colony_id: String, item_id: String) -> Result:
	var r: Result = can_cancel(state, empire_id, colony_id, item_id)
	if not r.ok:
		return r
	var c: Colony = state.colonies[colony_id]
	if c.queue[0].id != item_id:
		return Result.fail("error.build.rush_not_first")
	var item: BuildItem = c.queue[0]
	if item.turns_left <= 1:
		return Result.fail("error.build.rush_last_turn")
	if item.rushed_turn == state.turn:
		return Result.fail("error.build.rush_once")
	var cost: Dictionary[String, int] = {"energy": rush_cost(item).total}
	return _check_cost(state.empires[empire_id], cost)


static func rush(state: GameState, c: Colony, item_id: String) -> void:
	var item: BuildItem = c.queue[0]
	if item.id != item_id:
		return
	var e: Empire = state.empires[c.owner_id]
	e.stock["energy"] = e.stock_of("energy") - rush_cost(item).total
	item.turns_left -= 1
	item.rushed_turn = state.turn


## True when a building on the colony provides this service ("spaceport", "market").
static func provides(c: Colony, service: String) -> bool:
	for pb: Colony.PlacedBuilding in c.buildings:
		if DictIO.str_arr(Content.db().record("buildings", pb.building_id), "provides").has(service):
			return true
	return false


# --- Changes --------------------------------------------------------------------------------

## Queues an item and pays for it. Call only after the matching check succeeded. A governor pays
## the minerals from its purse; everything else comes from the empire's stock.
static func enqueue(state: GameState, c: Colony, kind: String, def_id: String, slot: int, tier: int, branch: String, cost: Dictionary[String, int], by_governor: bool = false) -> BuildItem:
	var e: Empire = state.empires[c.owner_id]
	for res: String in DictIO.sorted_keys(cost):
		if by_governor and res == "minerals":
			c.governor_funds -= cost[res]
		else:
			e.stock[res] = e.stock_of(res) - cost[res]
	var item: BuildItem = BuildItem.new()
	item.id = state.next_id("bld")
	item.kind = kind
	item.def_id = def_id
	item.slot = slot
	item.tier = tier
	item.branch = branch
	item.total_turns = build_turns(kind, def_id)
	item.turns_left = item.total_turns
	item.paid = cost.duplicate()
	item.by_governor = by_governor
	c.queue.append(item)
	return item


static func cancel(state: GameState, c: Colony, item_id: String) -> void:
	var i: int = _item_index(c, item_id)
	if i < 0:
		return
	var item: BuildItem = c.queue[i]
	var e: Empire = state.empires[c.owner_id]
	for res: String in DictIO.sorted_keys(item.paid):
		e.stock[res] = e.stock_of(res) + item.paid[res]
	c.queue.remove_at(i)


static func move_up(c: Colony, item_id: String) -> void:
	var i: int = _item_index(c, item_id)
	if i <= 0:
		return
	var item: BuildItem = c.queue[i]
	c.queue[i] = c.queue[i - 1]
	c.queue[i - 1] = item


static func demolish(c: Colony, slot: int) -> void:
	for i in c.districts.size():
		if c.districts[i].slot == slot:
			c.districts.remove_at(i)
			return
	for i in c.buildings.size():
		if c.buildings[i].slot == slot:
			c.buildings.remove_at(i)
			return


## Phase 2: the first item of every queue progresses one turn and completes at zero.
static func advance(state: GameState, r: TurnResult) -> void:
	for cid: String in DictIO.sorted_keys(state.colonies):
		var c: Colony = state.colonies[cid]
		if c.queue.is_empty() or c.owner_id.is_empty():
			continue
		var head: BuildItem = c.queue[0]
		head.turns_left -= 1
		if head.turns_left > 0:
			continue
		c.queue.remove_at(0)
		_complete(state, c, head, r)


static func _complete(state: GameState, c: Colony, item: BuildItem, r: TurnResult) -> void:
	var db: ContentDb = Content.db()
	var args: Dictionary = ColonyRules.name_args(state, c)
	match item.kind:
		BuildItem.KIND_DISTRICT:
			var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
			pd.slot = item.slot
			pd.district_id = item.def_id
			pd.tier = 1
			pd.branch = item.branch
			c.districts.append(pd)
			args["what_key"] = DictIO.str_of(db.record("districts", item.def_id), "name_key")
		BuildItem.KIND_UPGRADE:
			var target: Colony.PlacedDistrict = c.district_at(item.slot)
			if target != null:
				target.tier = item.tier
			args["what_key"] = DictIO.str_of(db.record("districts", item.def_id), "name_key")
			args["tier"] = item.tier
		BuildItem.KIND_BUILDING:
			var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
			pb.slot = item.slot
			pb.building_id = item.def_id
			c.buildings.append(pb)
			args["what_key"] = DictIO.str_of(db.record("buildings", item.def_id), "name_key")
		BuildItem.KIND_SHIP:
			Ships.launch(state, c, item.def_id)
			args["what_key"] = DictIO.str_of(db.record("hulls", item.def_id), "name_key")
	var key: String = "report.upgrade_done" if item.kind == BuildItem.KIND_UPGRADE else "report.build_done"
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 35, key, args)
		.with_severity(ReportItem.SEVERITY_GOOD).focus("colony", c.id))


static func _check_slot(c: Colony, planet: Planet, slot: int) -> Result:
	if slot < 0 or slot >= ColonyRules.slot_count(planet):
		return Result.fail("error.build.bad_slot")
	if planet.blocked_slots.has(slot):
		return Result.fail("error.build.blocked_slot")
	if c.district_at(slot) != null or c.building_at(slot) != null:
		return Result.fail("error.build.slot_taken")
	if c.queued_at(slot) != null:
		return Result.fail("error.build.slot_queued")
	return Result.success()


static func _check_cost(e: Empire, cost: Dictionary[String, int]) -> Result:
	var res: String = short_of(e, cost)
	if not res.is_empty():
		return Result.fail("error.build.cannot_afford", {"resource_key": DictIO.str_of(Content.db().record("resources", res), "name_key"), "need": Fx.div_ceil(cost[res], Fx.ONE), "have": Fx.div_floor(e.stock_of(res), Fx.ONE)})
	return Result.success()


static func _queued_building(c: Colony, building_id: String) -> bool:
	for item: BuildItem in c.queue:
		if item.kind == BuildItem.KIND_BUILDING and item.def_id == building_id:
			return true
	return false


static func _item_index(c: Colony, item_id: String) -> int:
	for i in c.queue.size():
		if c.queue[i].id == item_id:
			return i
	return -1


static func _res_map(d: Dictionary) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	for k: Variant in d.keys():
		out[str(k)] = int(d[k])
	return out
