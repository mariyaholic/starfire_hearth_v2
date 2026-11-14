extends RefCounted

func test_exploration_objectives_and_fog(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var e: Empire = s.player()
	var defs: Array[Dictionary] = Objectives.definitions(s)
	t.eq(Objectives.status(s, defs[0]).progress, 0, "home survey does not count")
	e.surveyed_planets.append("pl_vesper")
	t.eq(Objectives.status(s, defs[0]).progress, 1, "frontier survey counts")
	t.eq(Objectives.status(s, defs[2]).progress, 0, "Gate not yet visited")
	e.known_systems["sys_halden"] = Empire.FOG_SURVEYED
	t.eq(Objectives.status(s, defs[2]).progress, 1, "arrival completes visit")
	var galaxy: Dictionary = VisualSnapshotBuilder.galaxy(s)
	for marker: Dictionary in galaxy["systems"]:
		if marker["id"] == "sys_vesper":
			t.not_ok(marker.has("name_key"), "unknown system name is not disclosed")
			t.eq(marker.get("label_key"), "ui.travel.unknown", "unknown star carries a sanitized label")
			t.eq(marker.get("label_args", {}).get("number"), str(DictIO.sorted_keys(s.systems).find("sys_vesper") + 1), "label matches the destination selector")
	for lane: Dictionary in galaxy["lanes"]:
		t.not_ok(lane["locked"], "preview deep lanes are open")
	var first_light: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 1)
	for lane: Dictionary in VisualSnapshotBuilder.galaxy(first_light)["lanes"]:
		t.ok(lane["locked"], "First Light lanes stay locked")


func test_in_transit_fleet_is_not_drawn_at_departure(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var fleet: Fleet = s.fleets["flt_0001"]
	fleet.path = ["sys_tessel"] as Array[String]
	var snapshot: Dictionary = M1VisualSnapshot.system_view(s, "sys_ember")
	for ship: Dictionary in snapshot["ships"]:
		t.not_ok(fleet.ship_ids.has(ship["id"]), "a departing fleet is not rendered in its origin")


func test_travelling_ships_are_not_reported_idle(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var before: int = 0
	for item: ReportItem in GameModel.end_turn_checks(s, Economy.empire(s, s.player_id)):
		if item.text_key == "ui.endturn.ship_idle": before += 1
	t.eq(before, 3, "idle civilian ships still produce warnings")
	s.fleets["flt_0001"].path = ["sys_tessel"] as Array[String]
	var after: int = 0
	for item: ReportItem in GameModel.end_turn_checks(s, Economy.empire(s, s.player_id)):
		if item.text_key == "ui.endturn.ship_idle": after += 1
	t.eq(after, 2, "the travelling fleet is no longer marked idle")


func test_arrival_report_formats_the_localized_system_name(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var first: TurnResult = TurnProcessor.run(state, [MoveFleetCommand.create(state.player_id, "flt_0001", "sys_tessel")] as Array[Command])
	var result: TurnResult = first
	for unused: int in range(8):
		if result.state.fleets["flt_0001"].path.is_empty(): break
		result = TurnProcessor.run(result.state, [] as Array[Command])
	var arrival: ReportItem = null
	for item: ReportItem in result.report_items:
		if item.text_key == "report.fleet_arrived": arrival = item
	t.ok(arrival != null, "arrival produces a report item")
	if arrival != null:
		t.eq(Strings.fmt(arrival.text_key, arrival.args), "Fleet arrived in Tessel.", "report renders the translated system name")


func test_halden_event_choices_resolve_once_and_preserve_campaign(t: T) -> void:
	for choice: int in range(3):
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
		state.player().stock["energy"] = 0 if choice == 2 else 10000
		state.player().stock["minerals"] = 10000
		# An older in-progress save may already have completed the original required goals.
		for id: String in ["survey_frontier", "develop_vesper", "visit_gate"]:
			state.objectives_done[id] = state.turn
		var fired: TurnResult = TurnProcessor.run(state, [] as Array[Command])
		t.not_ok(fired.state.is_over(), "arrival cannot win before the cache decision")
		var pending: Array[EventInstance] = Events.pending_for(fired.state, state.player_id)
		t.eq(pending.size(), 1, "Gate visit triggers one decision")
		if pending.is_empty(): continue
		var saved: String = SaveSerializer.to_text(fired.state, "test")
		t.ne(saved, "", "pending cache produces a save envelope")
		var load_result: SaveSerializer.LoadResult = SaveSerializer.from_text(saved)
		t.ok(load_result.ok, "pending cache loads with a valid checksum: " + load_result.error_detail)
		if not load_result.ok: continue
		var restored: GameState = load_result.state
		if choice == 2: restored.player().stock["energy"] = 0
		var q: CommandQueue = CommandQueue.new(restored)
		var command: ChooseEventCommand = ChooseEventCommand.create(state.player_id, pending[0].id, choice)
		var energy_before: int = restored.player().stock_of("energy")
		var mineral_before: int = restored.player().stock_of("minerals")
		t.ok(q.submit(command).ok, "the selected choice is legal after reload")
		var view: GameState = q.preview()
		t.ok(view.flags.has("m2a_halden_resolved"), "choice sets the required resolution flag")
		var expected_flag: String = ["m2a_halden_salvage", "m2a_halden_study", "m2a_halden_left_intact"][choice]
		t.ok(view.flags.has(expected_flag), "the selected branch is recorded")
		t.eq(view.systems["sys_halden"].beacon, StarSystem.BEACON_DORMANT, "the Gate remains dormant")
		if choice == 0:
			t.eq(view.player().stock_of("energy"), energy_before - 1500)
			t.eq(view.player().stock_of("minerals"), mineral_before + 4000)
		elif choice == 1:
			t.eq(view.player().stock_of("energy"), energy_before - 2000)
			var found: bool = false
			for mod: Modifier in view.modifiers.values():
				if mod.source_key == "event.m2a_halden.1.title":
					found = mod.turns_left == 10 and mod.effects.size() == 1 and DictIO.str_of(mod.effects[0], "key") == "research_bp:all" and DictIO.int_of(mod.effects[0], "value") == 5000
			t.ok(found, "study applies the timed research modifier")
		else:
			t.eq(view.player().stock_of("energy"), 0, "free choice remains available with no energy")
		t.not_ok(q.submit(command).ok, "the same choice cannot be submitted twice")
		if choice < 2:
			t.ne(q.undo(), null, "paid choice can be undone")
			var undone: GameState = q.preview()
			t.eq(undone.player().stock_of("energy"), energy_before, "undo restores the energy cost")
			t.eq(undone.player().stock_of("minerals"), mineral_before, "undo restores the mineral reward")
			t.not_ok(undone.flags.has("m2a_halden_resolved"), "undo removes the resolution flag")
			t.not_ok(undone.flags.has(expected_flag), "undo removes the branch flag")
			t.eq(Events.pending_for(undone, state.player_id).size(), 1, "undo restores the pending decision")
			var undone_effects: int = 0
			for mod: Modifier in undone.modifiers.values():
				if mod.source_key == "event.m2a_halden.1.title": undone_effects += 1
			t.eq(undone_effects, 0, "undo removes the study effect")
			t.ok(q.submit(command).ok, "the choice can be made again after undo")
			view = q.preview()
			t.eq(view.player().stock_of("energy"), energy_before - (1500 if choice == 0 else 2000), "rechoose pays once")
			if choice == 0: t.eq(view.player().stock_of("minerals"), mineral_before + 4000, "rechoose grants salvage once")
			else:
				var reapplied: int = 0
				for mod: Modifier in view.modifiers.values():
					if mod.source_key == "event.m2a_halden.1.title": reapplied += 1
				t.eq(reapplied, 1, "rechoose applies one study modifier")
		var ledger_count: int = 0
		for entry: EventLogEntry in view.event_log:
			if entry.chain == "m2a_halden_cache":
				ledger_count += 1
				t.eq(entry.choice, choice, "ledger records the chosen branch")
		t.eq(ledger_count, 1, "only one ledger entry exists after reload and choice")
		var no_repeat: TurnResult = TurnResult.new()
		Events.run(view, no_repeat)
		t.eq(Events.pending_for(view, state.player_id).size(), 0, "revisiting does not repeat the event")
		var finished: TurnResult = TurnProcessor.run(restored, q.commands())
		t.eq(finished.state.outcome, GameState.OUTCOME_WON, "decision resolves the new goal")
		var p: CampaignProgress = CampaignProgress.new()
		p.record_win(finished.state.scenario_id)
		t.not_ok(p.is_unlocked("s2_the_crossing"), "preview decision never unlocks campaign scenarios")


func test_arrival_cannot_finish_before_cache_decision(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	state.player().known_systems["sys_tessel"] = Empire.FOG_SURVEYED
	state.objectives_done["survey_frontier"] = state.turn
	state.objectives_done["develop_vesper"] = state.turn
	var fleet: Fleet = state.fleets["flt_0002"]
	fleet.system_id = "sys_tessel"
	fleet.path = ["sys_halden"] as Array[String]
	var lane: Lane = Travel.lane_between(state, state.player_id, "sys_tessel", "sys_halden")
	fleet.move_progress = Travel.leg_turns(lane, Travel.fleet_speed(state, fleet)) - 1
	var result: TurnResult = TurnProcessor.run(state, [] as Array[Command])
	t.ok(result.state.player().known_systems.has("sys_halden"), "fleet arrives at the Gate")
	t.ok(result.state.objectives_done.has("visit_gate"), "the original visit goal completes")
	t.eq(Events.pending_for(result.state, state.player_id).size(), 1, "the cache decision is pending on arrival")
	t.not_ok(result.state.is_over(), "the pending decision prevents an immediate victory")


func test_halden_study_produces_ten_boosted_turns_and_survives_save(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	state.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
	Events.run(state, TurnResult.new())
	var pending: Array[EventInstance] = Events.pending_for(state, state.player_id)
	t.eq(pending.size(), 1)
	if pending.is_empty(): return
	var q: CommandQueue = CommandQueue.new(state)
	t.ok(q.submit(ChooseEventCommand.create(state.player_id, pending[0].id, 1)).ok)
	state = q.preview()
	for i: int in range(11):
		var baseline: GameState = state.clone()
		for id: String in DictIO.sorted_keys(baseline.modifiers):
			if baseline.modifiers[id].source_key == "event.m2a_halden.1.title": baseline.modifiers.erase(id)
		var normal: TurnResult = TurnProcessor.run(baseline, [] as Array[Command])
		var actual: TurnResult = TurnProcessor.run(state, [] as Array[Command])
		for branch: String in Empire.BRANCHES:
			var a: int = actual.reports[state.player_id].research[branch].total
			var b: int = normal.reports[state.player_id].research[branch].total
			if i < 10: t.ok(a > b, "study boosts %s on producing turn %d" % [branch, i + 1])
			else: t.eq(a, b, "study expires after ten producing turns")
		if i == 4:
			var saved: String = SaveSerializer.to_text(state, "test")
			t.ne(saved, "", "mid-buff state produces a save envelope")
			var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(saved)
			t.ok(loaded.ok, "mid-buff save loads with a valid checksum: " + loaded.error_detail)
			if loaded.ok:
				var resumed: TurnResult = TurnProcessor.run(loaded.state, [] as Array[Command])
				t.eq(resumed.state_hash, actual.state_hash, "mid-buff save restores remaining duration and state")
		state = actual.state


func test_halden_salvage_respects_storage_cap(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	state.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
	var cap: int = Economy.empire(state, state.player_id).cap_of("minerals")
	state.player().stock["minerals"] = cap - 500
	state.player().stock["energy"] = 10000
	Events.run(state, TurnResult.new())
	var pending: Array[EventInstance] = Events.pending_for(state, state.player_id)
	t.eq(pending.size(), 1)
	if pending.is_empty(): return
	var q: CommandQueue = CommandQueue.new(state)
	var choice: ChooseEventCommand = ChooseEventCommand.create(state.player_id, pending[0].id, 0)
	t.ok(q.submit(choice).ok)
	t.eq(q.preview().player().stock_of("minerals"), cap, "salvage is capped by available storage")
	t.eq(q.preview().player().stock_of("energy"), 8500, "salvage cost is paid once")
	t.not_ok(q.submit(choice).ok, "the same cache cannot be salvaged twice")
	t.ok(Strings.fmt("event.m2a_halden.1.body").contains("storage limits may reduce"), "the decision discloses the storage limit")
