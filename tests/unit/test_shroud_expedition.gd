extends RefCounted
## Optional Shroud encounter, pending-decision victory gate and legacy save compatibility.


func _new() -> GameState:
	return ScenarioLoader.build(Content.db(), "m2a_expedition", 1)


func _complete_required(s: GameState) -> void:
	for d: Dictionary in Objectives.definitions(s):
		if DictIO.bool_of(d, "required"):
			s.objectives_done[DictIO.str_of(d, "id")] = s.turn


func _encounter(s: GameState) -> EventInstance:
	s.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
	Events.run(s, TurnResult.new())
	for ev: EventInstance in Events.pending_for(s, s.player_id):
		if ev.chain == "m2a_shroud_derelict": return ev
	return null


func test_arrival_and_last_required_same_turn_wait_for_choice(t: T) -> void:
	var s: GameState = _new()
	for id: String in ["survey_frontier", "develop_vesper", "visit_gate"]:
		s.objectives_done[id] = s.turn
	s.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
	s.player().known_systems["sys_vesper"] = Empire.FOG_SURVEYED
	Events.run(s, TurnResult.new())
	var halden: EventInstance = null
	for ev: EventInstance in Events.pending_for(s, s.player_id):
		if ev.chain == "m2a_halden_cache": halden = ev
	t.ne(halden, null)
	if halden == null: return
	var probe: Ship = null
	for ship: Ship in s.ships_of(s.player_id):
		if Ships.role(ship) == Ships.ROLE_SURVEY: probe = ship
	var fleet: Fleet = s.fleets[probe.fleet_id]
	fleet.system_id = "sys_vesper"
	fleet.path.assign(["sys_shroud"])
	var lane: Lane = Travel.lane_between(s, s.player_id, "sys_vesper", "sys_shroud")
	fleet.move_progress = Travel.leg_turns(lane, Travel.fleet_speed(s, fleet)) - 1
	var command: ChooseEventCommand = ChooseEventCommand.create(s.player_id, halden.id, 2)
	var result: TurnResult = TurnProcessor.run(s, [command] as Array[Command])
	t.ok(result.state.player().known_systems.has("sys_shroud"))
	t.ok(result.state.objectives_done.has("m2a_resolve_cache"))
	t.eq(Events.pending_for(result.state, s.player_id).size(), 1)
	t.not_ok(result.state.is_over(), "the optional decision appears before victory")
	var saved: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(result.state, "test"))
	t.ok(saved.ok)
	if not saved.ok: return
	var pending: EventInstance = Events.pending_for(saved.state, s.player_id)[0]
	t.eq(pending.chain, "m2a_shroud_derelict")
	var finish: TurnResult = TurnProcessor.run(saved.state, [ChooseEventCommand.create(s.player_id, pending.id, 2)] as Array[Command])
	t.eq(finish.state.outcome, GameState.OUTCOME_WON)
	t.ok(finish.state.flags.has("m2a_shroud_honour"))


func test_choices_caps_undo_and_once_only(t: T) -> void:
	var reward_resources: Array[String] = ["alloys", "food", "influence"]
	var costs: Array[int] = [3000, 1000, 0]
	var flags: Array[String] = ["m2a_shroud_salvage", "m2a_shroud_supplies", "m2a_shroud_honour"]
	for choice: int in range(3):
		var s: GameState = _new()
		var ev: EventInstance = _encounter(s)
		t.ne(ev, null)
		if ev == null: continue
		var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "test"))
		t.ok(loaded.ok)
		if not loaded.ok: continue
		s = loaded.state
		var res: String = reward_resources[choice]
		var cap: int = Economy.empire(s, s.player_id).cap_of(res)
		s.player().stock[res] = cap - 100
		s.player().stock["energy"] = 0 if choice == 2 else 10000
		var q: CommandQueue = CommandQueue.new(s)
		var command: ChooseEventCommand = ChooseEventCommand.create(s.player_id, ev.id, choice)
		t.ok(q.submit(command).ok, "the free option works with no energy")
		t.eq(q.preview().player().stock_of("energy"), (0 if choice == 2 else 10000 - costs[choice]))
		t.eq(q.preview().player().stock_of(res), cap, "event rewards obey storage caps")
		t.ok(q.preview().flags.has(flags[choice]))
		t.ok(q.preview().flags.has("m2a_shroud_resolved"))
		t.not_ok(q.submit(command).ok, "duplicate choice is rejected")
		if choice < 2:
			q.undo()
			t.eq(q.preview().player().stock_of("energy"), 10000)
			t.eq(q.preview().player().stock_of(res), cap - 100)
			t.not_ok(q.preview().flags.has(flags[choice]))
			t.eq(Events.pending_for(q.preview(), s.player_id).size(), 1)
			t.ok(q.submit(command).ok)
		var finished: GameState = q.preview()
		finished.player().known_systems.erase("sys_shroud")
		finished.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
		Events.run(finished, TurnResult.new())
		t.eq(Events.pending_for(finished, s.player_id).size(), 0, "revisit cannot repeat the derelict")


func test_outpost_midbuild_save_resume_and_actual_yields(t: T) -> void:
	for kind: String in ["energy", "research"]:
		var s: GameState = _new()
		s.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
		s.player().surveyed_planets.append("pl_shroud_giant")
		s.player().stock["influence"] = 10000
		var ship: Ship = null
		for candidate: Ship in s.ships_of(s.player_id):
			if Ships.role(candidate) == Ships.ROLE_CONSTRUCTION: ship = candidate
		s.fleets[ship.fleet_id].system_id = "sys_shroud"
		var command: BuildOutpostCommand = BuildOutpostCommand.create(s.player_id, ship.id, "pl_shroud_giant", kind)
		t.ok(command.validate(s).ok)
		var first: TurnResult = TurnProcessor.run(s, [command] as Array[Command])
		t.eq(first.state.ships[ship.id].task_turns, 3)
		var saved: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(first.state, "test"))
		t.ok(saved.ok)
		if not saved.ok: continue
		var resumed: TurnResult = S1.advance(saved.state, 3)
		var uninterrupted: TurnResult = S1.advance(first.state, 3)
		t.eq(resumed.state.state_hash(), uninterrupted.state.state_hash())
		var cid: String = resumed.state.planets["pl_shroud_giant"].colony_id
		t.not_ok(cid.is_empty())
		if cid.is_empty(): continue
		var c: Colony = resumed.state.colonies[cid]
		t.eq(c.outpost_kind, kind)
		var report: Economy.ColonyReport = Economy.colony(resumed.state, c)
		if kind == "energy": t.eq(report.net_of("energy"), 550)
		else:
			t.eq(report.net_of("energy"), -50)
			for branch: String in Empire.BRANCHES:
				t.eq(report.research[branch].lines[0].value, 300, "base yield is unchanged")
				t.eq(report.research[branch].total, 270, "Generation Ark research penalty applies")


func test_legacy_four_system_save_retains_map_and_can_win(t: T) -> void:
	# This fixture used the scenario at 93f8cb3 and the unchanged production serializer.
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/saves/m2c_preview_v2.json")
	var restored: SaveSerializer.LoadResult = SaveSerializer.from_text(text)
	t.ok(restored.ok)
	if not restored.ok: return
	t.eq(restored.state.state_hash(), "8fcdd95c2cc42da515b629ac72a6f0b39df20e135cab7801a4c864e7a63d8d1f")
	t.eq(restored.state.systems.size(), 4)
	t.not_ok(restored.state.systems.has("sys_shroud"))
	var required: int = 0
	for d: Dictionary in Objectives.definitions(restored.state):
		if DictIO.bool_of(d, "required"):
			required += 1
			t.not_ok(str(d).contains("shroud"), "old saves gain no new Shroud objective")
	t.eq(required, 4)
	_complete_required(restored.state)
	var result: TurnResult = TurnProcessor.run(restored.state, [] as Array[Command])
	t.eq(result.state.outcome, GameState.OUTCOME_WON)
	t.eq(result.state.systems.size(), 4)


func test_gate_is_opt_in_and_loss_takes_priority(t: T) -> void:
	var first: GameState = S1.build()
	_complete_required(first)
	var pending: EventInstance = EventInstance.new()
	pending.id = "dummy"
	pending.empire_id = first.player_id
	first.events_pending.append(pending)
	Objectives.update(first, TurnResult.new())
	t.eq(first.outcome, GameState.OUTCOME_WON, "S1 retains its prior victory behavior")
	var preview: GameState = _new()
	_complete_required(preview)
	pending = EventInstance.new()
	pending.id = "dummy"
	pending.empire_id = preview.player_id
	preview.events_pending.append(pending)
	preview.colonies[preview.player().capital_id].pops = 0
	Objectives.update(preview, TurnResult.new())
	t.eq(preview.outcome, GameState.OUTCOME_LOST, "loss is not postponed by the decision gate")


func test_victory_gate_requires_boolean(t: T) -> void:
	var validator: DataValidator = DataValidator.new()
	validator.db = Content.db()
	validator.strings = StringTable.load_csv()
	var scenario: Dictionary = Content.db().scenarios["m2a_expedition"].duplicate(true)
	scenario["finish_pending_events_before_victory"] = "true"
	validator._check_scenario("m2a_expedition", scenario)
	var found: bool = false
	for issue: Dictionary in validator.errors():
		if str(issue["message"]).contains("finish_pending_events_before_victory must be a boolean"): found = true
	t.ok(found)


func test_outpost_preview_matches_actual_and_never_mutates(t: T) -> void:
	var s: GameState = _new()
	var planet: String = "pl_shroud_giant"
	t.eq(Economy.preview_outpost(s, s.player_id, planet, "energy"), null, "unknown planet is not disclosed")
	s.player().surveyed_planets.append(planet)
	var mod: Modifier = Modifier.new()
	mod.id = "empire_boost"
	mod.empire_id = s.player_id
	mod.colony_id = ""
	mod.turns_left = 5
	mod.effects = [{"key": "research_bp:all", "value": 2000}] as Array[Dictionary]
	s.modifiers[mod.id] = mod
	var collision: Modifier = Modifier.new()
	collision.id = "preview_collision"
	collision.empire_id = s.player_id
	collision.colony_id = "preview_outpost"
	collision.turns_left = 5
	collision.effects = [{"key": "research_bp:all", "value": 5000}] as Array[Dictionary]
	s.modifiers[collision.id] = collision
	var before: String = s.state_hash()
	for kind: String in ["energy", "research"]:
		var preview: Economy.ColonyReport = Economy.preview_outpost(s, s.player_id, planet, kind)
		t.ne(preview, null)
		if preview == null: continue
		var actual: Colony = Colony.new()
		actual.id = "real_outpost"
		actual.planet_id = planet
		actual.owner_id = s.player_id
		actual.outpost_kind = kind
		var report: Economy.ColonyReport = Economy.colony(s, actual)
		t.eq(preview.net_of("energy"), report.net_of("energy"))
		if kind == "research":
			for branch: String in Empire.BRANCHES:
				t.eq(preview.research[branch].total, report.research[branch].total)
				t.ok(preview.research[branch].verify())
			t.eq(preview.research["physics"].total, 330, "empire modifier is applied exactly once")
		else:
			t.eq(preview.net_of("energy"), 550)
			t.ok(preview.net["energy"].verify())
		t.eq(s.state_hash(), before)
	t.eq(Economy.preview_outpost(s, s.player_id, planet, "minerals"), null)
	var upkeep: Breakdown = Economy.outpost_upkeep()
	t.eq(upkeep.total, -50)
	t.ok(upkeep.verify())


func test_uncapped_choice_amounts(t: T) -> void:
	var resource: Array[String] = ["alloys", "food", "influence"]
	var reward: Array[int] = [2000, 5000, 1000]
	for choice: int in range(3):
		var s: GameState = _new()
		var ev: EventInstance = _encounter(s)
		t.ne(ev, null)
		if ev == null: continue
		s.player().stock[resource[choice]] = 1000
		s.player().stock["energy"] = 10000
		var q: CommandQueue = CommandQueue.new(s)
		t.ok(q.submit(ChooseEventCommand.create(s.player_id, ev.id, choice)).ok)
		t.eq(q.preview().player().stock_of(resource[choice]), 1000 + reward[choice])


func test_unrelated_foreign_decision_does_not_block_victory(t: T) -> void:
	var s: GameState = _new()
	_complete_required(s)
	var other: Empire = Empire.new()
	other.id = "other"
	s.empires[other.id] = other
	var ev: EventInstance = EventInstance.new()
	ev.empire_id = other.id
	s.events_pending.append(ev)
	Objectives.update(s, TurnResult.new())
	t.eq(s.outcome, GameState.OUTCOME_WON)


func test_mineral_outpost_preview_includes_tech_and_upkeep(t: T) -> void:
	var s: GameState = _new()
	s.player().surveyed_planets.append("pl_tessel")
	s.player().techs.append("automated_mining")
	var before: String = s.state_hash()
	var preview: Economy.ColonyReport = Economy.preview_outpost(s, s.player_id, "pl_tessel", "minerals")
	t.ne(preview, null)
	if preview != null:
		t.eq(preview.net_of("minerals"), 660)
		t.eq(preview.net_of("energy"), -50)
		t.ok(preview.net["minerals"].verify())
	t.eq(s.state_hash(), before)
