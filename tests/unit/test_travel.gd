extends RefCounted
## Slowboat routing, command safety and save-resume behavior.

const P: String = "emp_player"


func _map() -> GameState:
	var state: GameState = S1.build()
	for id: String in ["a", "b", "c", "d"]:
		var system: StarSystem = StarSystem.new()
		system.id = id
		system.name_key = "system." + id
		state.systems[id] = system
	for entry: Array in [["a", "b", 100], ["b", "d", 100], ["a", "c", 100], ["c", "d", 100], ["a", "d", 400]]:
		var lane: Lane = Lane.new()
		lane.id = "test_" + entry[0] + entry[1]
		lane.a = entry[0]
		lane.b = entry[1]
		lane.length_cly = entry[2]
		state.lanes[lane.id] = lane
	state.player().known_systems["a"] = Empire.FOG_SURVEYED
	state.player().known_systems["b"] = Empire.FOG_SURVEYED
	state.player().known_systems["c"] = Empire.FOG_SURVEYED
	var probe: Ship = S1.ship(state, "survey_probe")
	state.fleets[probe.fleet_id].system_id = "a"
	return state


func test_cheapest_route_ties_and_eta(t: T) -> void:
	var s: GameState = _map()
	var ship: Ship = S1.ship(s, "survey_probe")
	var fleet: Fleet = s.fleets[ship.fleet_id]
	t.eq(Travel.route(s, fleet.id, "d"), ["b", "d"])
	var eta: Breakdown = Travel.eta(s, fleet.id, "d")
	t.eq(eta.total, 4)
	t.ok(eta.verify())
	var construction: Ship = S1.ship(s, "construction_ship")
	s.fleets[construction.fleet_id].ship_ids.erase(construction.id)
	s.fleets.erase(construction.fleet_id)
	construction.fleet_id = fleet.id
	fleet.ship_ids.append(construction.id)
	t.eq(Travel.eta(s, fleet.id, "d").total, 4, "the slowest member sets speed")
	s.lanes["test_ab"].length_cly = 120
	t.eq(Travel.eta(s, fleet.id, "b").total, 3)
	t.eq(Travel.route(s, fleet.id, "d"), ["c", "d"])


func test_locks_ownership_and_beacons(t: T) -> void:
	var s: GameState = _map()
	var fleet: Fleet = s.fleets[S1.ship(s, "survey_probe").fleet_id]
	s.flags["fog_locked:d"] = 1
	t.eq(Travel.can_move(s, P, fleet.id, "d").reason_key, "error.fleet.no_route")
	s.flags.erase("fog_locked:d")
	s.systems["d"].owner_id = "enemy"
	t.eq(Travel.can_move(s, P, fleet.id, "d").reason_key, "error.fleet.no_route")
	s.systems["d"].owner_id = ""
	for id: String in ["test_ab", "test_ac", "test_ad"]:
		s.lanes[id].kind = Lane.KIND_BEACON
	s.systems["a"].beacon = StarSystem.BEACON_ACTIVE
	s.systems["d"].beacon = StarSystem.BEACON_ACTIVE
	t.eq(Travel.can_move(s, P, fleet.id, "d").reason_key, "error.fleet.no_route")


func test_commands_are_safe_and_serializable(t: T) -> void:
	var s: GameState = _map()
	var ship: Ship = S1.ship(s, "survey_probe")
	var fleet: Fleet = s.fleets[ship.fleet_id]
	var cmd: MoveFleetCommand = MoveFleetCommand.create(P, fleet.id, "b")
	t.eq(CommandRegistry.from_dict(cmd.to_dict()).to_dict(), cmd.to_dict())
	ship.task = Ship.TASK_SURVEY
	t.eq(cmd.validate(s).reason_key, "error.fleet.unavailable")
	ship.task = ""
	t.ok(cmd.validate(s).ok)
	cmd.apply(s)
	t.eq(cmd.validate(s).reason_key, "error.fleet.in_transit")
	t.eq(Ships.can_survey(s, P, ship.id, "pl_brume").reason_key, "error.fleet.in_transit")
	fleet.path.clear()
	ship.owner_id = "enemy"
	t.eq(cmd.validate(s).reason_key, "error.fleet.unavailable")
	ship.owner_id = P
	var stowaway: Ship = Ship.new()
	stowaway.id = "orphan"
	stowaway.owner_id = P
	stowaway.fleet_id = fleet.id
	stowaway.hull = "survey_probe"
	s.ships[stowaway.id] = stowaway
	t.eq(cmd.validate(s).reason_key, "error.fleet.unavailable")
	s.ships.erase(stowaway.id)
	ship.hull = "corvette"
	t.eq(cmd.validate(s).reason_key, "error.fleet.unavailable")
	fleet.ship_ids.clear()
	t.eq(cmd.validate(s).reason_key, "error.fleet.empty")


func test_movement_save_resume_and_discovery(t: T) -> void:
	var s: GameState = _map()
	var fleet_id: String = S1.ship(s, "survey_probe").fleet_id
	var unexplored: Planet = Planet.new()
	unexplored.id = "test_planet"
	unexplored.system_id = "d"
	s.planets[unexplored.id] = unexplored
	s.systems["d"].planet_ids.append(unexplored.id)
	var before: GameState = s.clone()
	var r: TurnResult = S1.turn(s, [MoveFleetCommand.create(P, fleet_id, "d")])
	t.eq(s.state_hash(), before.state_hash(), "turn does not mutate input")
	t.eq(r.state.fleets[fleet_id].system_id, "a")
	t.eq(r.state.fleets[fleet_id].move_progress, 1)
	t.eq(Travel.remaining_eta(r.state, fleet_id).total, 3)
	t.ok(Travel.remaining_eta(r.state, fleet_id).verify())
	t.not_ok(r.state.player().known_systems.has("d"))
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(r.state, "test"))
	t.ok(loaded.ok)
	t.eq(Travel.remaining_eta(loaded.state, fleet_id).total, 3)
	var resumed: TurnResult = S1.advance(loaded.state, 1)
	var uninterrupted: TurnResult = S1.advance(r.state, 1)
	t.eq(resumed.state.state_hash(), uninterrupted.state.state_hash())
	t.eq(resumed.state.fleets[fleet_id].system_id, "b")
	t.eq(resumed.state.fleets[fleet_id].path, ["d"])
	t.eq(Travel.remaining_eta(resumed.state, fleet_id).total, 2)
	t.eq(resumed.state.player().known_systems["b"], Empire.FOG_SURVEYED)
	t.not_ok(resumed.state.player().surveyed_planets.has("test_planet"))
	var found: bool = false
	for item: ReportItem in resumed.report_items:
		if item.text_key == "report.fleet_arrived":
			found = item.focus_id == "b" and item.breakdown != null and item.breakdown.total == 2
	t.ok(found)
	r = S1.advance(resumed.state, 2)
	t.eq(r.state.fleets[fleet_id].system_id, "d")
	t.ok(r.state.player().known_systems.has("d"))
	t.not_ok(r.state.player().surveyed_planets.has("test_planet"))
	t.ok(r.state.fleets[fleet_id].path.is_empty())
	t.eq(Invariants.check(r.state), [])


func test_malformed_or_newly_blocked_route_stops_safely(t: T) -> void:
	var s: GameState = _map()
	var fleet: Fleet = s.fleets[S1.ship(s, "survey_probe").fleet_id]
	fleet.path.assign(["b", "missing"])
	t.not_ok(Invariants.check(s).is_empty())
	t.eq(Travel.remaining_eta(s, fleet.id).total, 0)
	var result: TurnResult = TurnResult.new()
	Travel.advance(s, result)
	t.eq(fleet.path, ["b", "missing"])
	t.eq(fleet.system_id, "a")
	t.eq(fleet.move_progress, 0)
	t.eq(result.report_items[0].text_key, "report.fleet_route_blocked")
	fleet.path.assign(["b", "d"])
	fleet.move_progress = 1
	s.flags["fog_locked:d"] = 1
	Travel.advance(s, result)
	t.eq(fleet.path, ["b", "d"])
	t.eq(fleet.move_progress, 1)
	t.eq(fleet.system_id, "a")


func test_deterministic_scripted_traversal(t: T) -> void:
	var left: GameState = _map()
	var right: GameState = left.clone()
	var fleet_id: String = S1.ship(left, "survey_probe").fleet_id
	for turn: int in range(8):
		var lcommands: Array[Command] = []
		var rcommands: Array[Command] = []
		if turn == 0 or turn == 4:
			var destination: String = "d" if turn == 0 else "a"
			lcommands.append(MoveFleetCommand.create(P, fleet_id, destination))
			rcommands.append(MoveFleetCommand.create(P, fleet_id, destination))
		var lr: TurnResult = TurnProcessor.run(left, lcommands)
		var rr: TurnResult = TurnProcessor.run(right, rcommands)
		t.eq(lr.rejected.size(), 0)
		t.eq(lr.state_hash, rr.state_hash)
		t.eq(Invariants.check(lr.state), [])
		left = lr.state
		right = rr.state
	t.eq(left.fleets[fleet_id].system_id, "a")


func test_task_and_move_orders_do_not_overlap_either_way(t: T) -> void:
	var s: GameState = _map()
	var probe: Ship = S1.ship(s, "survey_probe")
	var fleet: Fleet = s.fleets[probe.fleet_id]
	fleet.system_id = s.planets["pl_brume"].system_id
	var lane: Lane = Lane.new()
	lane.id = "test_home_b"
	lane.a = fleet.system_id
	lane.b = "b"
	lane.length_cly = 100
	s.lanes[lane.id] = lane
	var work_first: TurnResult = S1.turn(s, [SurveyCommand.create(P, probe.id, "pl_brume"), MoveFleetCommand.create(P, fleet.id, "b")])
	t.eq(work_first.rejected.size(), 1)
	t.eq(work_first.rejected[0]["reason_key"], "error.fleet.unavailable")
	t.ok(work_first.state.fleets[fleet.id].path.is_empty())
	var move_first: TurnResult = S1.turn(s, [MoveFleetCommand.create(P, fleet.id, "b"), SurveyCommand.create(P, probe.id, "pl_brume")])
	t.eq(move_first.rejected.size(), 1)
	t.eq(move_first.rejected[0]["reason_key"], "error.fleet.in_transit")
	t.eq(move_first.state.ships[probe.id].task, Ship.TASK_NONE)


func test_unknown_waypoints_cannot_be_used_as_shortcuts(t: T) -> void:
	var s: GameState = _map()
	var fleet: Fleet = s.fleets[S1.ship(s, "survey_probe").fleet_id]
	s.player().known_systems.erase("b")
	s.player().known_systems.erase("c")
	t.eq(Travel.route(s, fleet.id, "d"), ["d"], "only the direct lane can reach an unknown destination")
	s.lanes.erase("test_ad")
	t.eq(Travel.can_move(s, P, fleet.id, "d").reason_key, "error.fleet.no_route")
	t.eq(Travel.route(s, fleet.id, "b"), ["b"], "an adjacent unknown system may be explored")


func test_foreign_movement_does_not_disclose_arrival_or_route(t: T) -> void:
	var s: GameState = _map()
	var fleet: Fleet = s.fleets[S1.ship(s, "survey_probe").fleet_id]
	s.empires[P].is_player = false
	fleet.path.assign(["b"])
	var result: TurnResult = TurnResult.new()
	Travel.advance(s, result)
	Travel.advance(s, result)
	t.eq(fleet.system_id, "b")
	t.ok(s.empires[P].known_systems.has("b"))
	t.eq(result.report_items.size(), 0)
	fleet.path.assign(["missing"])
	Travel.advance(s, result)
	t.eq(result.report_items.size(), 0)


func test_malformed_busy_fleet_cannot_finish_task_at_departure(t: T) -> void:
	var s: GameState = _map()
	var ship: Ship = S1.ship(s, "survey_probe")
	var fleet: Fleet = s.fleets[ship.fleet_id]
	fleet.system_id = s.planets["pl_brume"].system_id
	var lane: Lane = Lane.new()
	lane.id = "test_home_b"
	lane.a = fleet.system_id
	lane.b = "b"
	lane.length_cly = 100
	s.lanes[lane.id] = lane
	fleet.path.assign(["b"])
	fleet.move_progress = 1
	ship.task = Ship.TASK_SURVEY
	ship.task_target = "pl_brume"
	ship.task_turns = 1
	var r: TurnResult = S1.turn(s, [])
	t.eq(r.state.fleets[fleet.id].move_progress, 1)
	t.eq(r.state.ships[ship.id].task_turns, 1)
	t.eq(r.state.ships[ship.id].task, Ship.TASK_SURVEY)
	t.not_ok(r.state.player().surveyed_planets.has("pl_brume"))
	t.not_ok(Invariants.check(r.state).is_empty())


func test_bad_task_targets_do_not_finish_or_crash(t: T) -> void:
	var s: GameState = _map()
	var ship: Ship = S1.ship(s, "survey_probe")
	ship.task = Ship.TASK_SURVEY
	ship.task_target = "missing"
	ship.task_turns = 1
	var result: TurnResult = TurnResult.new()
	Ships.advance(s, result)
	t.eq(ship.task_turns, 1)
	ship.task_target = "pl_brume"
	Ships.advance(s, result)
	t.eq(ship.task_turns, 1)
	t.not_ok(s.player().surveyed_planets.has("pl_brume"))
