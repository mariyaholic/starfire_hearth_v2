class_name Ships
extends RefCounted
## Civilian ships in M1 (§5.6, DESIGN_LOG 59–61): surveys, outposts and colony founding inside
## the ship's system. A task is ordered in phase 1, pays its costs then, and completes in phase 8
## when its turns run out.

const SURVEY_TURNS: int = 2
const OUTPOST_TURNS: int = 4
const COLONISE_TURNS: int = 1
const OUTPOST_INFLUENCE: int = 5000
## Outpost cost reductions stop at -75% (DESIGN_LOG 72).
const OUTPOST_COST_FLOOR_BP: int = -7500
const COLONY_POPS: int = 2

const ROLE_SURVEY: String = "survey"
const ROLE_CONSTRUCTION: String = "construction"
const ROLE_COLONY: String = "colony"


static func role(sh: Ship) -> String:
	return DictIO.str_of(Content.db().record("hulls", sh.hull), "role")


static func system_of(state: GameState, sh: Ship) -> String:
	if state.fleets.has(sh.fleet_id):
		return state.fleets[sh.fleet_id].system_id
	return ""


static func outpost_cost(state: GameState, e: Empire) -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.outpost_cost", "influence", false)
	b.link_to("mechanic:outposts")
	b.base("source.outpost_base", OUTPOST_INFLUENCE)
	var fx: Array[Modifiers.Entry] = Modifiers.empire_wide(state, e)
	var total_bp: int = 0
	for entry: Modifiers.Entry in Modifiers.with_key(fx, "outpost_cost_bp"):
		var bp: int = maxi(entry.value, OUTPOST_COST_FLOOR_BP - total_bp)
		if bp != entry.value:
			b.note("note.outpost_cost_floor", {"pct": Fx.div_floor(-OUTPOST_COST_FLOOR_BP, 100)})
		if bp != 0:
			b.mult(entry.source_key, bp, entry.source_args, null, entry.link)
			total_bp += bp
	return b.finish()


static func outpost_turns(state: GameState, e: Empire) -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.outpost_turns", Breakdown.UNIT_TURNS, false)
	b.base("source.outpost_turns_base", OUTPOST_TURNS)
	Modifiers.mult_lines(b, Modifiers.empire_wide(state, e), "outpost_time_bp")
	b.cap_min(1, "source.at_least_one_turn")
	return b.finish()


# --- Checks ---------------------------------------------------------------------------------

static func check_ship(state: GameState, empire_id: String, ship_id: String, needed_role: String) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not state.ships.has(ship_id):
		return Result.fail("error.ship.not_found")
	var sh: Ship = state.ships[ship_id]
	if sh.owner_id != empire_id:
		return Result.fail("error.ship.not_owned")
	if role(sh) != needed_role:
		return Result.fail("error.ship.wrong_role", {"role_key": Names.ship_role(needed_role)})
	if sh.is_busy():
		return Result.fail("error.ship.busy")
	return Result.success()


static func check_target(state: GameState, sh: Ship, planet_id: String) -> Result:
	if not state.planets.has(planet_id):
		return Result.fail("error.planet.not_found")
	var p: Planet = state.planets[planet_id]
	if p.system_id != system_of(state, sh):
		return Result.fail("error.ship.not_in_system")
	for other: Ship in state.ships_of(sh.owner_id):
		if other.id != sh.id and other.is_busy() and other.task_target == planet_id and other.task != Ship.TASK_SURVEY:
			return Result.fail("error.ship.target_taken")
	return Result.success()


static func can_survey(state: GameState, empire_id: String, ship_id: String, planet_id: String) -> Result:
	var r: Result = check_ship(state, empire_id, ship_id, ROLE_SURVEY)
	if not r.ok:
		return r
	var sh: Ship = state.ships[ship_id]
	r = check_target(state, sh, planet_id)
	if not r.ok:
		return r
	if state.empires[empire_id].surveyed_planets.has(planet_id):
		return Result.fail("error.planet.already_surveyed")
	for other: Ship in state.ships_of(empire_id):
		if other.task == Ship.TASK_SURVEY and other.task_target == planet_id:
			return Result.fail("error.ship.target_taken")
	return Result.success()


static func can_build_outpost(state: GameState, empire_id: String, ship_id: String, planet_id: String, kind: String) -> Result:
	var r: Result = check_ship(state, empire_id, ship_id, ROLE_CONSTRUCTION)
	if not r.ok:
		return r
	var sh: Ship = state.ships[ship_id]
	r = check_target(state, sh, planet_id)
	if not r.ok:
		return r
	var e: Empire = state.empires[empire_id]
	var p: Planet = state.planets[planet_id]
	if not e.surveyed_planets.has(planet_id):
		return Result.fail("error.planet.not_surveyed")
	if not p.colony_id.is_empty():
		return Result.fail("error.planet.taken")
	var kinds: Array[String] = ColonyRules.outpost_kinds(p)
	if kinds.is_empty():
		return Result.fail("error.outpost.not_here")
	if not kinds.has(kind):
		return Result.fail("error.outpost.wrong_kind")
	var cost: int = outpost_cost(state, e).total
	if e.stock_of("influence") < cost:
		return Result.fail("error.build.cannot_afford", {"resource_key": "res.influence.name", "need": Fx.div_ceil(cost, Fx.ONE), "have": Fx.div_floor(e.stock_of("influence"), Fx.ONE)})
	return Result.success()


static func can_colonise(state: GameState, empire_id: String, ship_id: String, planet_id: String) -> Result:
	var r: Result = check_ship(state, empire_id, ship_id, ROLE_COLONY)
	if not r.ok:
		return r
	var sh: Ship = state.ships[ship_id]
	r = check_target(state, sh, planet_id)
	if not r.ok:
		return r
	var e: Empire = state.empires[empire_id]
	var p: Planet = state.planets[planet_id]
	if not e.surveyed_planets.has(planet_id):
		return Result.fail("error.planet.not_surveyed")
	if not p.colony_id.is_empty():
		return Result.fail("error.planet.taken")
	var h: String = ColonyRules.habitability(p)
	if h == ColonyRules.HAB_DOMES and not e.has_tech("habitat_domes"):
		return Result.fail("error.colony.needs_domes")
	if h != ColonyRules.HAB_OPEN and h != ColonyRules.HAB_DOMES:
		return Result.fail("error.colony.not_habitable")
	return Result.success()


# --- Changes --------------------------------------------------------------------------------

static func start_survey(state: GameState, ship_id: String, planet_id: String) -> void:
	_start(state.ships[ship_id], Ship.TASK_SURVEY, planet_id, "", SURVEY_TURNS)


static func start_outpost(state: GameState, ship_id: String, planet_id: String, kind: String) -> void:
	var sh: Ship = state.ships[ship_id]
	var e: Empire = state.empires[sh.owner_id]
	e.stock["influence"] = e.stock_of("influence") - outpost_cost(state, e).total
	_start(sh, Ship.TASK_OUTPOST, planet_id, kind, outpost_turns(state, e).total)


static func start_colonise(state: GameState, ship_id: String, planet_id: String) -> void:
	_start(state.ships[ship_id], Ship.TASK_COLONISE, planet_id, "", COLONISE_TURNS)


## A newly built ship leaves the colony's shipyard in a fleet of its own.
static func launch(state: GameState, c: Colony, hull_id: String) -> Ship:
	var sys_id: String = state.planets[c.planet_id].system_id
	var f: Fleet = Fleet.new()
	f.id = state.next_id("flt")
	f.owner_id = c.owner_id
	f.system_id = sys_id
	state.fleets[f.id] = f
	var sh: Ship = Ship.new()
	sh.id = state.next_id("shp")
	sh.hull = hull_id
	sh.owner_id = c.owner_id
	sh.fleet_id = f.id
	sh.structure = DictIO.int_of(Content.db().record("hulls", hull_id), "structure") * Fx.ONE
	state.ships[sh.id] = sh
	f.ship_ids.append(sh.id)
	return sh


## Phase 8: tasks count down and complete.
static func advance(state: GameState, r: TurnResult) -> void:
	for shid: String in DictIO.sorted_keys(state.ships):
		if not state.ships.has(shid):
			continue
		var sh: Ship = state.ships[shid]
		if not sh.is_busy():
			continue
		sh.task_turns -= 1
		if sh.task_turns > 0:
			continue
		var task: String = sh.task
		var target: String = sh.task_target
		var param: String = sh.task_param
		sh.task = Ship.TASK_NONE
		sh.task_target = ""
		sh.task_param = ""
		sh.task_turns = 0
		match task:
			Ship.TASK_SURVEY:
				_finish_survey(state, sh, target, r)
			Ship.TASK_OUTPOST:
				_finish_outpost(state, sh, target, param, r)
			Ship.TASK_COLONISE:
				_finish_colony(state, sh, target, r)


static func _start(sh: Ship, task: String, target: String, param: String, turns: int) -> void:
	sh.task = task
	sh.task_target = target
	sh.task_param = param
	sh.task_turns = maxi(1, turns)


static func _finish_survey(state: GameState, sh: Ship, planet_id: String, r: TurnResult) -> void:
	var e: Empire = state.empires[sh.owner_id]
	if not e.surveyed_planets.has(planet_id):
		e.surveyed_planets.append(planet_id)
	var p: Planet = state.planets[planet_id]
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_FLEETS, 40, "report.survey_done", ColonyRules.planet_args(p))
		.with_severity(ReportItem.SEVERITY_GOOD).focus("planet", planet_id))


static func _finish_outpost(state: GameState, sh: Ship, planet_id: String, kind: String, r: TurnResult) -> void:
	var p: Planet = state.planets[planet_id]
	if not p.colony_id.is_empty():
		return
	var c: Colony = _new_colony(state, sh.owner_id, p)
	c.outpost_kind = kind
	c.stability = 50
	var args: Dictionary = ColonyRules.planet_args(p)
	args["resource_key"] = "res.%s.name" % kind
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 50, "report.outpost_done", args)
		.with_severity(ReportItem.SEVERITY_GOOD).focus("colony", c.id))


## The colony ship is used up. Its hull becomes the first shelter: a Habitation district on an
## open world, a Habitat Dome on a dome world (DESIGN_LOG 61, revised by 77).
static func _finish_colony(state: GameState, sh: Ship, planet_id: String, r: TurnResult) -> void:
	var p: Planet = state.planets[planet_id]
	if not p.colony_id.is_empty():
		return
	var c: Colony = _new_colony(state, sh.owner_id, p)
	c.pops = COLONY_POPS
	var free: Array[int] = ColonyRules.free_slots(c, p)
	if not free.is_empty():
		if ColonyRules.is_dome_world(p):
			var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
			pb.slot = free[0]
			pb.building_id = "habitat_dome"
			c.buildings.append(pb)
		else:
			var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
			pd.slot = free[0]
			pd.district_id = Economy.HABITATION
			c.districts.append(pd)
	var cr: Economy.ColonyReport = Economy.colony(state, c)
	c.stability = Stability.target(state, c, cr).total
	_remove_ship(state, sh)
	r.report_items.append(ReportItem.make(ReportItem.CATEGORY_COLONIES, 85, "report.colony_founded", ColonyRules.planet_args(p))
		.with_severity(ReportItem.SEVERITY_GOOD).focus("colony", c.id))


static func _new_colony(state: GameState, empire_id: String, p: Planet) -> Colony:
	var c: Colony = Colony.new()
	c.id = state.next_id("col")
	c.planet_id = p.id
	c.owner_id = empire_id
	c.founded_turn = state.turn
	state.colonies[c.id] = c
	p.colony_id = c.id
	var sys: StarSystem = state.systems[p.system_id]
	if sys.owner_id.is_empty():
		sys.owner_id = empire_id
	return c


static func _remove_ship(state: GameState, sh: Ship) -> void:
	if state.fleets.has(sh.fleet_id):
		var f: Fleet = state.fleets[sh.fleet_id]
		f.ship_ids.erase(sh.id)
		if f.ship_ids.is_empty():
			state.fleets.erase(f.id)
	state.ships.erase(sh.id)
