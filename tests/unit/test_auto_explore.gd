extends RefCounted
## Optional automation is deterministic, fog-safe, reversible and respects active orders.

const P: String = "emp_player"


func _state() -> GameState:
	var s: GameState = S1.build()
	var probe: Ship = S1.ship(s, "survey_probe")
	var start: String = s.fleets[probe.fleet_id].system_id
	for pid: String in s.systems[start].planet_ids:
		if not s.player().surveyed_planets.has(pid):
			s.player().surveyed_planets.append(pid)
	for id: String in ["auto_a", "auto_b"]:
		var sys: StarSystem = StarSystem.new()
		sys.id = id
		sys.name_key = "system." + id
		s.systems[id] = sys
		var lane: Lane = Lane.new()
		lane.id = "lane_" + id
		lane.a = start
		lane.b = id
		lane.length_cly = 100
		s.lanes[lane.id] = lane
	return s


func _fleet(s: GameState) -> Fleet:
	return s.fleets[S1.ship(s, "survey_probe").fleet_id]


func test_validation_and_manual_override_undo(t: T) -> void:
	var s: GameState = _state()
	var fleet: Fleet = _fleet(s)
	var ship: Ship = s.ships[fleet.ship_ids[0]]
	var on: SetAutoExploreCommand = SetAutoExploreCommand.create(P, fleet.id, true)
	t.eq(CommandRegistry.from_dict(on.to_dict()).to_dict(), on.to_dict())
	t.ok(on.validate(s).ok)
	var q: CommandQueue = CommandQueue.new(s)
	t.ok(q.submit(on).ok)
	t.ok(AutoExplore.enabled(q.preview(), fleet.id))
	t.not_ok(AutoExplore.enabled(s, fleet.id))
	t.not_ok(q.submit(MoveFleetCommand.create(P, fleet.id, "missing")).ok)
	t.ok(AutoExplore.enabled(q.preview(), fleet.id), "rejected orders preserve intent")
	t.ok(q.submit(MoveFleetCommand.create(P, fleet.id, "auto_a")).ok)
	t.not_ok(AutoExplore.enabled(q.preview(), fleet.id))
	q.undo()
	t.ok(AutoExplore.enabled(q.preview(), fleet.id), "undo restores the prior intent")
	s.player().surveyed_planets.erase("pl_brume")
	var q2: CommandQueue = CommandQueue.new(s)
	t.ok(q2.submit(on).ok)
	t.ok(q2.submit(SurveyCommand.create(P, ship.id, "pl_brume")).ok)
	t.not_ok(AutoExplore.enabled(q2.preview(), fleet.id))
	q2.undo()
	t.ok(AutoExplore.enabled(q2.preview(), fleet.id))
	var other: Ship = S1.ship(s, "construction_ship")
	t.eq(AutoExplore.can_set(s, P, other.fleet_id, true).reason_key, "error.auto_explore.unavailable")
	t.eq(AutoExplore.can_set(s, "missing", fleet.id, true).reason_key, "error.empire.not_found")


func test_survey_first_then_disable_mid_task(t: T) -> void:
	var s: GameState = _state()
	var fleet: Fleet = _fleet(s)
	var ship_id: String = fleet.ship_ids[0]
	s.player().surveyed_planets.erase("pl_brume")
	var result: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, fleet.id, true)])
	t.ok(AutoExplore.enabled(result.state, fleet.id))
	t.eq(result.state.ships[ship_id].task, Ship.TASK_SURVEY)
	t.eq(result.state.ships[ship_id].task_turns, 1)
	var disabled: TurnResult = S1.turn(result.state, [SetAutoExploreCommand.create(P, fleet.id, false)])
	t.not_ok(AutoExplore.enabled(disabled.state, fleet.id))
	t.ok(disabled.state.player().surveyed_planets.has("pl_brume"))
	t.ok(disabled.state.fleets[fleet.id].path.is_empty())


func test_disable_midflight_preserves_leg(t: T) -> void:
	var s: GameState = _state()
	var id: String = _fleet(s).id
	var r: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, id, true)])
	t.eq(r.state.fleets[id].path, ["auto_a"])
	t.eq(r.state.fleets[id].move_progress, 1)
	var disabled: TurnResult = S1.turn(r.state, [SetAutoExploreCommand.create(P, id, false)])
	t.not_ok(AutoExplore.enabled(disabled.state, id))
	t.eq(disabled.state.fleets[id].system_id, "auto_a")
	t.ok(disabled.state.fleets[id].path.is_empty())


func test_hidden_planets_do_not_change_assignment(t: T) -> void:
	var empty: GameState = _state()
	var full: GameState = empty.clone()
	var hidden: Planet = Planet.new()
	hidden.id = "secret_planet"
	hidden.system_id = "auto_a"
	full.planets[hidden.id] = hidden
	full.systems["auto_a"].planet_ids.append(hidden.id)
	var id: String = _fleet(empty).id
	var a: TurnResult = S1.turn(empty, [SetAutoExploreCommand.create(P, id, true)])
	var b: TurnResult = S1.turn(full, [SetAutoExploreCommand.create(P, id, true)])
	t.eq(a.state.fleets[id].path, b.state.fleets[id].path)
	t.eq(a.state.fleets[id].path, ["auto_a"])
	t.eq(a.state.ships[a.state.fleets[id].ship_ids[0]].task, "")


func test_two_probes_reserve_distinct_unknown_destinations(t: T) -> void:
	var s: GameState = _state()
	var first: Fleet = _fleet(s)
	var second_ship: Ship = Ships.launch(s, S1.aster(s), "survey_probe")
	var second_id: String = second_ship.fleet_id
	var r: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, first.id, true), SetAutoExploreCommand.create(P, second_id, true)])
	t.eq(r.state.fleets[first.id].path, ["auto_a"])
	t.eq(r.state.fleets[second_id].path, ["auto_b"])


func test_pending_event_pauses_new_assignments_and_cleanup(t: T) -> void:
	var s: GameState = _state()
	var fleet: Fleet = _fleet(s)
	var ev: EventInstance = EventInstance.new()
	ev.id = "wait"
	ev.empire_id = P
	s.events_pending.append(ev)
	s.player().flags[AutoExplore.PREFIX + "orphan"] = 1
	s.player().flags[AutoExplore.PREFIX + fleet.id] = 1
	var out: TurnResult = TurnResult.new()
	AutoExplore.advance(s, out)
	t.ok(fleet.path.is_empty())
	t.ok(AutoExplore.enabled(s, fleet.id))
	t.not_ok(s.player().flags.has(AutoExplore.PREFIX + "orphan"))
	s.events_pending.clear()
	AutoExplore.advance(s, out)
	t.eq(fleet.path, ["auto_a"])


func test_completion_once_and_save_resume_determinism(t: T) -> void:
	var s: GameState = _state()
	var id: String = _fleet(s).id
	var first: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, id, true)])
	var load_result: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(first.state, "test"))
	t.ok(load_result.ok)
	var a: GameState = first.state
	var b: GameState = load_result.state
	var completions: int = 0
	for i: int in 12:
		# Remove unrelated story interruptions equally in both replays.
		a.events_pending.clear()
		b.events_pending.clear()
		var ar: TurnResult = S1.turn(a, [])
		var br: TurnResult = S1.turn(b, [])
		t.eq(ar.state_hash, br.state_hash)
		for item: ReportItem in ar.report_items:
			if item.text_key == "report.auto_explore_complete":
				completions += 1
				t.eq(item.focus_kind, "system")
				t.eq(item.focus_id, ar.state.fleets[id].system_id)
		a = ar.state
		b = br.state
	t.eq(completions, 1)
	t.not_ok(AutoExplore.enabled(a, id))


func test_two_probes_survey_distinct_local_planets(t: T) -> void:
	var s: GameState = _state()
	var first: Fleet = _fleet(s)
	var second_ship: Ship = Ships.launch(s, S1.aster(s), "survey_probe")
	for planet_id: String in ["pl_brume", "pl_cinder"]:
		s.player().surveyed_planets.erase(planet_id)
	var r: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, first.id, true), SetAutoExploreCommand.create(P, second_ship.fleet_id, true)])
	t.eq(r.state.ships[first.ship_ids[0]].task_target, "pl_brume")
	t.eq(r.state.ships[second_ship.id].task_target, "pl_cinder")


func test_pending_event_does_not_freeze_existing_travel(t: T) -> void:
	var s: GameState = _state()
	var id: String = _fleet(s).id
	var r: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, id, true)])
	var ev: EventInstance = EventInstance.new()
	ev.id = "pending"
	ev.empire_id = P
	r.state.events_pending.append(ev)
	var next: TurnResult = S1.turn(r.state, [])
	t.eq(next.state.fleets[id].system_id, "auto_a")
	t.ok(AutoExplore.enabled(next.state, id))
	var later: TurnResult = S1.turn(next.state, [])
	t.eq(later.state.fleets[id].system_id, "auto_a")
	t.ok(later.state.fleets[id].path.is_empty())


func test_owner_mismatch_cleans_orphan_intent(t: T) -> void:
	var s: GameState = _state()
	var fleet: Fleet = _fleet(s)
	var foreign: Empire = Empire.new()
	foreign.id = "foreign"
	s.empires[foreign.id] = foreign
	foreign.flags[AutoExplore.PREFIX + fleet.id] = 1
	var r: TurnResult = TurnResult.new()
	AutoExplore.advance(s, r)
	t.not_ok(foreign.flags.has(AutoExplore.PREFIX + fleet.id))
	t.eq(AutoExplore.can_set(s, foreign.id, fleet.id, true).reason_key, "error.fleet.not_owned")


func test_non_survey_fleet_does_not_reserve_exploration_destination(t: T) -> void:
	var s: GameState = _state()
	var probe: Fleet = _fleet(s)
	var construction: Ship = S1.ship(s, "construction_ship")
	var other: Fleet = s.fleets[construction.fleet_id]
	other.path.assign(["auto_a"])
	var r: TurnResult = S1.turn(s, [SetAutoExploreCommand.create(P, probe.id, true)])
	t.eq(r.state.fleets[probe.id].path, ["auto_a"])
