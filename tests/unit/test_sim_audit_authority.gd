extends RefCounted
## Regression tests for authoritative command snapshots and simulation boundaries.


func test_submitted_and_exported_command_mutation_cannot_change_queued_order(t: T) -> void:
	var s: GameState = S1.build()
	var id: String = S1.aster(s).id
	var q: CommandQueue = CommandQueue.new(s)
	var source: RenameColonyCommand = RenameColonyCommand.create(s.player_id, id, "Approved")
	t.ok(q.submit(source).ok)
	t.eq(q.preview().colonies[id].name, "Approved")
	source.new_name = "Mutated source"
	var published: Array[Command] = q.commands()
	(published[0] as RenameColonyCommand).new_name = "Mutated export"
	t.eq((q.commands()[0] as RenameColonyCommand).new_name, "Approved")
	var result: TurnResult = TurnProcessor.run(s, q.commands())
	t.eq(result.state.colonies[id].name, "Approved")
	t.eq(q.preview().colonies[id].name, "Approved")


func test_checked_save_rejects_unresolvable_event_decisions(t: T) -> void:
	for spec: Array in [["missing_chain", 1], ["labor_strike", 999]]:
		var s: GameState = S1.build()
		var event: EventInstance = EventInstance.new()
		event.id = "evt_bad"
		event.empire_id = s.player_id
		event.chain = spec[0]
		event.step = spec[1]
		s.events_pending.append(event)
		var load_result: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
		t.not_ok(load_result.ok, "unknown pending event cannot leave the player trapped")
		t.eq(load_result.error_key, "save.error.corrupt")
		if load_result.ok:
			t.eq(Events.step_of(event.chain, event.step), {}, "there are no choices the player can resolve")


func test_checked_save_accepts_real_pending_decision(t: T) -> void:
	var s: GameState = S1.advance(S1.build(), 5).state
	t.ok(not Events.pending_for(s, s.player_id).is_empty())
	var load_result: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.ok(load_result.ok, load_result.error_detail)


func test_terminal_scenario_states_are_absorbing_without_a_turn(t: T) -> void:
	for outcome: String in [GameState.OUTCOME_WON, GameState.OUTCOME_LOST]:
		var s: GameState = S1.build()
		s.outcome = outcome
		s.outcome_turn = s.turn
		s.outcome_reason = "outcome.all_objectives" if outcome == GameState.OUTCOME_WON else "outcome.capital_empty"
		var before: String = s.state_hash()
		var command: Command = RenameColonyCommand.create(s.player_id, s.player().capital_id, "Should not apply")
		var result: TurnResult = TurnProcessor.run(s, [command] as Array[Command])
		t.eq(result.state_hash, before, "terminal input returns the unchanged hash")
		t.eq(result.state.state_hash(), before)
		t.eq(result.state.turn, s.turn)
		t.eq(result.state.colonies[s.player().capital_id].name, s.colonies[s.player().capital_id].name)
		t.ok(result.phase_log.is_empty(), "no economy, task, event or report phase runs")
		t.eq(result.rejected.size(), 1)
		if not result.rejected.is_empty(): t.eq(result.rejected[0]["reason_key"], "error.game.finished")


func test_centi_authoring_overflow_is_rejected_without_wraparound(t: T) -> void:
	t.eq(Fx.parse_centi("92233720368547758.07"), [true, 9223372036854775807])
	t.eq(Fx.parse_centi("-92233720368547758.08"), [true, -9223372036854775807 - 1])
	t.not_ok(Fx.parse_centi("92233720368547758.08")[0], "positive overflow cannot wrap into a negative cost")
	t.not_ok(Fx.parse_centi("-92233720368547758.09")[0], "negative overflow cannot wrap positive")
	t.not_ok(Fx.parse_centi("999999999999999999999999999999999999")[0])


func test_player_cannot_issue_foreign_empire_order_but_ai_can(t: T) -> void:
	var s: GameState = TinyState.build()
	var c: Colony = Colony.new()
	c.id = s.next_id("col")
	c.owner_id = "emp_meridian"
	c.planet_id = "pl_brume"
	c.pops = 1
	s.colonies[c.id] = c
	s.planets[c.planet_id].colony_id = c.id
	var command: Command = RenameColonyCommand.create(c.owner_id, c.id, "Foreign")
	t.ok(command.validate(s).ok, "the order is otherwise legal for that empire")
	var q: CommandQueue = CommandQueue.new(s)
	var before_preview: String = q.preview().state_hash()
	t.eq(q.submit(command).reason_key, "error.command.not_player")
	t.eq(q.preview().state_hash(), before_preview)
	t.eq(q.size(), 0)
	var player_attempt: TurnResult = TurnProcessor.run(s, [command] as Array[Command])
	t.eq(player_attempt.state.colonies[c.id].name, "")
	t.eq(player_attempt.rejected.size(), 1)
	if not player_attempt.rejected.is_empty():
		t.eq(player_attempt.rejected[0]["reason_key"], "error.command.not_player")
	var ai_result: TurnResult = TurnResult.new()
	ai_result.state = s.clone()
	TurnProcessor._phase_commands(ai_result, [] as Array[Command], [command] as Array[Command])
	t.eq(ai_result.state.colonies[c.id].name, "Foreign", "an AI order uses its own empire")
	t.ok(ai_result.rejected.is_empty())


func test_checked_save_rejects_unresolvable_active_ship_tasks(t: T) -> void:
	var s: GameState = S1.build()
	var ship: Ship = S1.ship(s, "survey_probe")
	ship.task = Ship.TASK_SURVEY
	ship.task_turns = 2
	ship.task_target = "missing_planet"
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.not_ok(loaded.ok, "a task whose target is absent cannot finish or be cancelled")
	t.eq(loaded.error_key, "save.error.corrupt")
	ship.task_target = "pl_brume"
	ship.task = "missing_task"
	loaded = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.not_ok(loaded.ok, "unknown task must not silently consume its remaining time")
	t.eq(loaded.error_key, "save.error.corrupt")


func test_checked_save_rejects_unnormalized_growth_counter(t: T) -> void:
	var s: GameState = S1.build()
	S1.aster(s).growth = 1000000
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	if loaded.ok:
		var old_pops: int = S1.aster(loaded.state).pops
		var progressed: TurnResult = TurnProcessor.run(loaded.state, [] as Array[Command])
		t.ok(S1.aster(progressed.state).pops >= old_pops + 100, "the malformed state creates 100 populations in one turn")
	t.not_ok(loaded.ok, "the stable save boundary cannot contain 100 banked growth completions")
	t.eq(loaded.error_key, "save.error.corrupt")


func test_checked_save_rejects_unknown_hull_and_empty_event_choices(t: T) -> void:
	var s: GameState = S1.build()
	var ship: Ship = S1.ship(s, "survey_probe")
	ship.hull = "unknown_hull"
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.not_ok(loaded.ok)
	t.eq(loaded.error_key, "save.error.corrupt")
	var db: ContentDb = Content.db()
	db.events["audit_no_choices"] = {"steps": [{"step": 1, "choices": []}]}
	s = S1.build()
	var event: EventInstance = EventInstance.new()
	event.id = "evt_bad"
	event.empire_id = s.player_id
	event.chain = "audit_no_choices"
	event.step = 1
	s.events_pending.append(event)
	loaded = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.not_ok(loaded.ok)
	t.eq(loaded.error_key, "save.error.corrupt")
	db.events.erase("audit_no_choices")


func test_checked_save_accepts_valid_in_progress_survey(t: T) -> void:
	var s: GameState = S1.build()
	var ship: Ship = S1.ship(s, "survey_probe")
	t.ok(SurveyCommand.create(s.player_id, ship.id, "pl_brume").validate(s).ok)
	Ships.start_survey(s, ship.id, "pl_brume")
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.ok(loaded.ok, loaded.error_detail)
	if loaded.ok:
		t.eq(loaded.state.ships[ship.id].task_turns, Ships.SURVEY_TURNS)


func test_negative_authored_cost_is_rejected(t: T) -> void:
	var validator: DataValidator = DataValidator.new()
	validator.db = Content.db()
	validator._check_value({"energy": -100}, "res_map", "event.choice.cost")
	t.ok(not validator.errors().is_empty(), "subtracting a negative cost would grant free energy")


func test_checked_save_requires_player_identity_flag(t: T) -> void:
	var s: GameState = S1.build()
	s.player().is_player = false
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.not_ok(loaded.ok, "the designated player cannot be treated as an AI on load")
	t.eq(loaded.error_key, "save.error.corrupt")


func test_stale_saved_id_counter_does_not_overwrite_existing_colony(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var original_capital: String = s.player().capital_id
	var colony_ship: Ship = null
	for ship: Ship in s.ships_of(s.player_id):
		if ship.hull == "colony_ship": colony_ship = ship
	t.ne(colony_ship, null)
	if colony_ship == null: return
	s.fleets[colony_ship.fleet_id].system_id = "sys_vesper"
	s.player().surveyed_planets.append("pl_vesper")
	s.counters["col"] = 0
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
	t.ok(loaded.ok, "a stale counter can be safely recovered without changing the save schema")
	if not loaded.ok: return
	var result: TurnResult = TurnProcessor.run(loaded.state, [ColoniseCommand.create(s.player_id, colony_ship.id, "pl_vesper")] as Array[Command])
	var settled: String = result.state.planets["pl_vesper"].colony_id
	t.ne(settled, "")
	t.ne(settled, original_capital, "a newly allocated id must not replace an existing colony")
	t.eq(result.state.colonies[original_capital].planet_id, "pl_aster")
	t.eq(Invariants.check(result.state), [])


func test_stale_counters_skip_live_queue_event_and_effect_ids(t: T) -> void:
	var omitted: GameState = S1.build()
	omitted.counters.erase("col")
	t.eq(omitted.next_id("col"), "col_0002", "omitted legacy counter cannot reuse the capital id")
	var s: GameState = S1.build()
	var q: CommandQueue = CommandQueue.new(s)
	t.ok(q.submit(PlaceDistrictCommand.create(s.player_id, s.player().capital_id, 8, "agriculture")).ok)
	s = q.preview()
	s.counters["bld"] = 0
	t.eq(s.next_id("bld"), "bld_0002")
	var ev: EventInstance = EventInstance.new()
	ev.id = "evt_0001"
	ev.chain = "labor_strike"
	ev.step = 1
	ev.empire_id = s.player_id
	s.events_scheduled.append(ev)
	s.counters["evt"] = 0
	t.eq(s.next_id("evt"), "evt_0002")
	var effect: ScheduledEffect = ScheduledEffect.new()
	effect.id = "sfx_0001"
	s.scheduled_effects.append(effect)
	s.counters["sfx"] = 0
	t.eq(s.next_id("sfx"), "sfx_0002")


func test_checked_save_rejects_mismatched_entity_dictionary_keys(t: T) -> void:
	var s: GameState = S1.build()
	for collection: Dictionary in [s.planets, s.colonies, s.ships, s.lanes]:
		var key: String = DictIO.sorted_keys(collection)[0]
		var entity: Variant = collection[key]
		var original: String = entity.id
		entity.id = "wrong_entity_id"
		var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s, "audit"))
		t.not_ok(loaded.ok, "entity ids must match their dictionary keys before simulation uses them")
		t.eq(loaded.error_key, "save.error.corrupt")
		entity.id = original


func test_exhausted_counter_restarts_without_overflow_or_collision(t: T) -> void:
	var s: GameState = S1.build()
	s.counters["col"] = 9223372036854775807
	t.eq(s.next_id("col"), "col_0002", "counter exhaustion must not wrap to a negative id or reuse the capital")
	t.eq(s.counters["col"], 2)
