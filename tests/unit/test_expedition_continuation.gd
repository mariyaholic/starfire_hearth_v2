extends RefCounted
## Continuation is an explicit zero-turn state transition, never a reconstructed victory.


func _won() -> GameState:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	for d: Dictionary in Objectives.definitions(s):
		if DictIO.bool_of(d, "required"):
			s.objectives_done[DictIO.str_of(d, "id")] = s.turn
	Objectives.update(s, TurnResult.new())
	return s


func test_begin_clones_authoritative_state_without_a_turn(t: T) -> void:
	var s: GameState = _won()
	var fleet: Fleet = s.fleets["flt_0002"]
	fleet.path.assign(["sys_tessel"])
	fleet.move_progress = 1
	s.player().flags[AutoExplore.PREFIX + fleet.id] = 1
	var pending: EventInstance = EventInstance.new()
	pending.id = "pending_choice"
	pending.chain = "m2a_halden_cache"
	pending.empire_id = s.player_id
	pending.step = 1
	s.events_pending.append(pending)
	var before: Dictionary = s.to_dict()
	var before_hash: String = s.state_hash()
	var win_turn: int = s.outcome_turn
	var transition: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(s)
	t.ok(transition.ok)
	t.eq(transition.error_key, "")
	t.eq(s.state_hash(), before_hash, "the authoritative winning snapshot is untouched")
	if not transition.ok: return
	var continued: GameState = transition.state
	t.ne(continued, s)
	var expected: Dictionary = before.duplicate(true)
	expected["outcome"] = ""
	expected["outcome_turn"] = 0
	expected["outcome_reason"] = ""
	expected["flags"][ExpeditionContinuation.FLAG_CONTINUED] = 1
	expected["flags"][ExpeditionContinuation.FLAG_COMPLETED_TURN] = win_turn
	t.eq(continued.to_dict(), expected, "only outcome metadata and continuation flags change")
	t.eq(continued.turn, s.turn)
	t.eq(continued.fleets[fleet.id].move_progress, 1)
	t.ok(AutoExplore.enabled(continued, fleet.id))
	t.eq(continued.events_pending.size(), 1)
	t.ok(ExpeditionContinuation.is_continued(continued))
	t.eq(ExpeditionContinuation.completion_turn(continued), win_turn)
	t.eq(ExpeditionContinuation.completion_turn(s), 0)
	continued.player().stock["energy"] = 0
	continued.fleets[fleet.id].path.clear()
	t.eq(s.state_hash(), before_hash, "nested objects are independent")


func test_continuation_does_not_repeat_win_but_completes_optional_goal(t: T) -> void:
	var original: GameState = _won()
	var transition: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(original)
	t.ok(transition.ok)
	if not transition.ok: return
	var s: GameState = transition.state
	var c: Colony = Colony.new()
	c.id = s.next_id("col")
	c.owner_id = s.player_id
	c.planet_id = "pl_tessel"
	c.outpost_kind = "minerals"
	s.colonies[c.id] = c
	s.planets[c.planet_id].colony_id = c.id
	var result: TurnResult = TurnProcessor.run(s, [] as Array[Command])
	t.ok(result.state.objectives_done.has("outpost_tessel"))
	t.eq(result.state.outcome, GameState.OUTCOME_NONE)
	t.eq(result.state.flags[ExpeditionContinuation.FLAG_COMPLETED_TURN], original.outcome_turn)
	for item: ReportItem in result.report_items:
		t.ne(item.text_key, "report.scenario_won")
	for i: int in range(3):
		result = TurnProcessor.run(result.state, [] as Array[Command])
		t.eq(result.state.outcome, GameState.OUTCOME_NONE)


func test_later_loss_keeps_first_win_turn(t: T) -> void:
	var original: GameState = _won()
	var transition: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(original)
	var continued: GameState = transition.state
	continued.colonies[continued.player().capital_id].pops = 0
	var result: TurnResult = TurnProcessor.run(continued, [] as Array[Command])
	t.eq(result.state.outcome, GameState.OUTCOME_LOST)
	t.eq(result.state.flags[ExpeditionContinuation.FLAG_COMPLETED_TURN], original.outcome_turn)
	t.eq(result.state.flags[ExpeditionContinuation.FLAG_CONTINUED], 1)


func test_rejects_invalid_or_already_continued_without_mutation(t: T) -> void:
	var unsupported: GameState = S1.build()
	t.eq(ExpeditionContinuation.can_continue(unsupported).reason_key, "error.continue.unsupported")
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var before: String = state.state_hash()
	t.eq(ExpeditionContinuation.begin(state).error_key, "error.continue.not_won")
	t.eq(state.state_hash(), before)
	state.outcome = GameState.OUTCOME_LOST
	t.eq(ExpeditionContinuation.can_continue(state).reason_key, "error.continue.not_won")
	state.outcome = GameState.OUTCOME_WON
	state.outcome_turn = 0
	before = state.state_hash()
	t.eq(ExpeditionContinuation.begin(state).error_key, "error.continue.invalid_victory")
	t.eq(state.state_hash(), before)
	state.outcome_turn = state.turn + 1
	t.eq(ExpeditionContinuation.can_continue(state).reason_key, "error.continue.invalid_victory")
	state.outcome_turn = state.turn
	var result: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(state)
	t.ok(result.ok)
	t.eq(ExpeditionContinuation.begin(result.state).error_key, "error.continue.already_continued")
	var malformed: GameState = state.clone()
	malformed.flags[ExpeditionContinuation.FLAG_CONTINUED] = 1
	malformed.flags[ExpeditionContinuation.FLAG_COMPLETED_TURN] = 0
	t.not_ok(ExpeditionContinuation.is_continued(malformed))
	t.eq(ExpeditionContinuation.can_continue(malformed).reason_key, "error.continue.invalid_victory")


func test_legacy_won_four_system_save_does_not_recompute_goals(t: T) -> void:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/saves/m2c_preview_v2.json")
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(text)
	t.ok(loaded.ok)
	if not loaded.ok: return
	var old: GameState = loaded.state
	old.outcome = GameState.OUTCOME_WON
	old.outcome_turn = old.turn - 1
	old.outcome_reason = "outcome.all_objectives"
	t.not_ok(old.objectives_done.has("m2a_resolve_cache"))
	var transition: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(old)
	t.ok(transition.ok)
	if not transition.ok: return
	t.eq(transition.state.systems.size(), 4)
	t.not_ok(transition.state.systems.has("sys_shroud"))
	t.not_ok(transition.state.objectives_done.has("m2a_resolve_cache"))
	var next: TurnResult = TurnProcessor.run(transition.state, [] as Array[Command])
	t.eq(next.state.outcome, GameState.OUTCOME_NONE)


func test_immediate_save_resume_is_deterministic(t: T) -> void:
	var state: GameState = ExpeditionContinuation.begin(_won()).state
	var save: String = SaveSerializer.to_text(state, "test")
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(save)
	t.ok(loaded.ok)
	if not loaded.ok: return
	t.eq(loaded.state.state_hash(), state.state_hash())
	t.ok(ExpeditionContinuation.is_continued(loaded.state))
	var a: TurnResult = TurnProcessor.run(state, [] as Array[Command])
	var b: TurnResult = TurnProcessor.run(loaded.state, [] as Array[Command])
	t.eq(a.state_hash, b.state_hash)
	t.eq(a.state.outcome, GameState.OUTCOME_NONE)


func test_unscoped_or_invalid_flags_do_not_suppress_normal_win(t: T) -> void:
	var s: GameState = S1.build()
	for d: Dictionary in Objectives.definitions(s):
		if DictIO.bool_of(d, "required"): s.objectives_done[DictIO.str_of(d, "id")] = s.turn
	s.flags[ExpeditionContinuation.FLAG_CONTINUED] = 1
	s.flags[ExpeditionContinuation.FLAG_COMPLETED_TURN] = s.turn
	t.not_ok(ExpeditionContinuation.is_continued(s))
	Objectives.update(s, TurnResult.new())
	t.eq(s.outcome, GameState.OUTCOME_WON)


func test_opt_in_is_boolean_and_limited_to_preview(t: T) -> void:
	var validator: DataValidator = DataValidator.new()
	validator.db = Content.db()
	validator.strings = StringTable.load_csv()
	var scenario: Dictionary = Content.db().scenarios["m2a_expedition"].duplicate(true)
	scenario["allow_post_victory"] = "yes"
	validator._check_scenario("m2a_expedition", scenario)
	var found: bool = false
	for issue: Dictionary in validator.errors():
		if str(issue["message"]).contains("allow_post_victory must be a boolean"): found = true
	t.ok(found)
	validator.issues.clear()
	scenario["allow_post_victory"] = true
	validator._check_scenario("s1_first_light", scenario)
	found = false
	for issue: Dictionary in validator.errors():
		if str(issue["message"]).contains("limited to the expedition preview"): found = true
	t.ok(found)
