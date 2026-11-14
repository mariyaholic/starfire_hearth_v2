extends RefCounted
## Stop-at-next-system orders preserve the current slowboat leg and undo cleanly.

const P: String = "emp_player"


func _travelling() -> GameState:
	var s: GameState = S1.build()
	var probe: Ship = S1.ship(s, "survey_probe")
	var fleet: Fleet = s.fleets[probe.fleet_id]
	var origin: String = fleet.system_id
	for id: String in ["stop_b", "stop_c"]:
		var system: StarSystem = StarSystem.new()
		system.id = id
		system.name_key = "system." + id
		s.systems[id] = system
		s.player().known_systems[id] = Empire.FOG_SURVEYED
	var leg: Lane = Lane.new()
	leg.id = "stop_first"
	leg.a = origin
	leg.b = "stop_b"
	leg.length_cly = 200
	s.lanes[leg.id] = leg
	var second: Lane = Lane.new()
	second.id = "stop_second"
	second.a = "stop_b"
	second.b = "stop_c"
	second.length_cly = 100
	s.lanes[second.id] = second
	fleet.path.assign(["stop_b", "stop_c"])
	fleet.move_progress = 1
	AutoExplore.set_enabled(s, P, fleet.id, true)
	return s


func _fleet_id(s: GameState) -> String:
	return S1.ship(s, "survey_probe").fleet_id


func test_midleg_stop_and_save_resume_preserve_arrival(t: T) -> void:
	var s: GameState = _travelling()
	var id: String = _fleet_id(s)
	var origin: String = s.fleets[id].system_id
	var command: StopFleetCommand = StopFleetCommand.create(P, id)
	t.ok(command.validate(s).ok)
	var original_eta: int = Travel.remaining_eta(s, id).total
	t.eq(original_eta, 4)
	var stopped: TurnResult = S1.turn(s, [command])
	t.eq(stopped.rejected.size(), 0)
	t.eq(stopped.state.fleets[id].system_id, origin)
	t.eq(stopped.state.fleets[id].path, ["stop_b"])
	t.eq(stopped.state.fleets[id].move_progress, 2)
	t.eq(Travel.remaining_eta(stopped.state, id).total, 1)
	t.not_ok(AutoExplore.enabled(stopped.state, id))
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(stopped.state, "test"))
	t.ok(loaded.ok)
	var resumed: TurnResult = S1.turn(loaded.state, [])
	var continued: TurnResult = S1.turn(stopped.state, [])
	var baseline: TurnResult = S1.advance(s, 2)
	t.eq(resumed.state.state_hash(), continued.state.state_hash())
	t.eq(resumed.state.turn, baseline.state.turn)
	t.eq(resumed.state.fleets[id].system_id, "stop_b")
	t.eq(baseline.state.fleets[id].system_id, "stop_b")
	t.ok(resumed.state.fleets[id].path.is_empty())
	t.eq(resumed.state.fleets[id].move_progress, 0)
	t.not_ok(AutoExplore.enabled(resumed.state, id))
	var next: TurnResult = S1.turn(resumed.state, [])
	t.eq(next.state.fleets[id].system_id, "stop_b")
	t.ok(next.state.fleets[id].path.is_empty(), "automatic exploration does not resume")


func test_undo_restores_route_progress_and_intent(t: T) -> void:
	var s: GameState = _travelling()
	var id: String = _fleet_id(s)
	var before: String = s.state_hash()
	var q: CommandQueue = CommandQueue.new(s)
	var command: StopFleetCommand = StopFleetCommand.create(P, id)
	t.eq(CommandRegistry.from_dict(command.to_dict()).to_dict(), command.to_dict())
	t.ok(q.submit(command).ok)
	t.eq(q.preview().fleets[id].path, ["stop_b"])
	t.eq(q.preview().fleets[id].move_progress, 1)
	t.not_ok(AutoExplore.enabled(q.preview(), id))
	t.eq(q.submit(command).reason_key, "error.fleet.already_stopping")
	t.eq(q.size(), 1)
	q.undo()
	t.eq(q.preview().state_hash(), before)
	t.eq(q.preview().fleets[id].path, ["stop_b", "stop_c"])
	t.ok(AutoExplore.enabled(q.preview(), id))
	t.eq(s.state_hash(), before)


func test_single_leg_auto_order_and_unchanged_task(t: T) -> void:
	var s: GameState = _travelling()
	var id: String = _fleet_id(s)
	s.fleets[id].path.assign(["stop_b"])
	var ship: Ship = s.ships[s.fleets[id].ship_ids[0]]
	var task_before: Dictionary = ship.to_dict()
	var command: StopFleetCommand = StopFleetCommand.create(P, id)
	t.ok(command.validate(s).ok)
	command.apply(s)
	t.eq(s.fleets[id].path, ["stop_b"])
	t.eq(s.fleets[id].move_progress, 1)
	t.eq(ship.to_dict(), task_before)
	t.not_ok(AutoExplore.enabled(s, id))
	t.eq(command.validate(s).reason_key, "error.fleet.already_stopping")


func test_invalid_orders_do_not_mutate_state(t: T) -> void:
	var s: GameState = _travelling()
	var id: String = _fleet_id(s)
	var other: Empire = Empire.new()
	other.id = "other"
	s.empires[other.id] = other
	var q: CommandQueue = CommandQueue.new(s)
	var start_hash: String = q.preview().state_hash()
	var foreign: StopFleetCommand = StopFleetCommand.create("other", id)
	t.eq(foreign.validate(s).reason_key, "error.fleet.not_owned", "the fleet belongs to another empire")
	t.eq(q.submit(foreign).reason_key, "error.command.not_player", "the player queue rejects a foreign actor")
	t.eq(q.preview().state_hash(), start_hash)
	t.eq(q.submit(StopFleetCommand.create(P, "missing")).reason_key, "error.fleet.not_found")
	t.eq(q.preview().state_hash(), start_hash)
	s.fleets[id].path.assign(["stop_b", "missing"])
	q = CommandQueue.new(s)
	start_hash = q.preview().state_hash()
	t.eq(q.submit(StopFleetCommand.create(P, id)).reason_key, "error.fleet.invalid_route")
	t.eq(q.preview().state_hash(), start_hash)
	s.fleets[id].path.clear()
	s.fleets[id].move_progress = 0
	t.eq(Travel.can_stop(s, P, id).reason_key, "error.fleet.not_moving")


func test_invalid_members_and_progress_cannot_be_repaired_by_stop(t: T) -> void:
	var s: GameState = _travelling()
	var id: String = _fleet_id(s)
	var ship: Ship = s.ships[s.fleets[id].ship_ids[0]]
	ship.hull = "corvette"
	t.eq(Travel.can_stop(s, P, id).reason_key, "error.fleet.invalid_route")
	ship.hull = "survey_probe"
	ship.task = Ship.TASK_SURVEY
	t.eq(Travel.can_stop(s, P, id).reason_key, "error.fleet.invalid_route")
	ship.task = ""
	s.fleets[id].path.clear()
	t.eq(Travel.can_stop(s, P, id).reason_key, "error.fleet.invalid_route")
	s.fleets[id].move_progress = 0
	s.fleets[id].id = "mismatched_id"
	t.eq(Travel.can_stop(s, P, id).reason_key, "error.fleet.invalid_route")


func test_stop_after_queued_move_in_same_turn(t: T) -> void:
	var s: GameState = _travelling()
	var id: String = _fleet_id(s)
	s.fleets[id].path.clear()
	s.fleets[id].move_progress = 0
	AutoExplore.set_enabled(s, P, id, false)
	var q: CommandQueue = CommandQueue.new(s)
	t.ok(q.submit(MoveFleetCommand.create(P, id, "stop_c")).ok)
	t.eq(q.preview().fleets[id].path, ["stop_b", "stop_c"])
	t.ok(q.submit(StopFleetCommand.create(P, id)).ok)
	t.eq(q.preview().fleets[id].path, ["stop_b"])
	var result: TurnResult = TurnProcessor.run(s, q.commands())
	t.eq(result.rejected.size(), 0)
	t.eq(result.state.fleets[id].path, ["stop_b"])
	t.eq(result.state.fleets[id].move_progress, 1)
