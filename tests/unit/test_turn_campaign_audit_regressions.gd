extends RefCounted
## Synthetic content exercises supported combinations without modifying shipped scenario data.

func test_mixed_scope_effects_keep_independent_scope(t: T) -> void:
	var s: GameState = S1.build()
	var c: Colony = S1.aster(s)
	var empire_stability: int = Modifiers.total(Modifiers.empire_wide(s, s.player()), "stability_add")
	var colony_stability: int = Modifiers.total(Modifiers.for_colony(s, c), "stability_add")
	var effects: Array = [
		{"key": "stability_add", "value": 4, "target": "colony", "turns": 5},
		{"key": "growth_bp", "value": 700, "turns": 5},
	]
	Effects.apply(s, S1.PLAYER, c.id, effects, "test.scope", null)
	t.eq(Modifiers.total(Modifiers.empire_wide(s, s.player()), "growth_bp"), 700, "empire effect remains empire-wide")
	t.eq(Modifiers.total(Modifiers.empire_wide(s, s.player()), "stability_add"), empire_stability, "colony effect stays local")
	t.eq(Modifiers.total(Modifiers.for_colony(s, c), "stability_add"), colony_stability + 4, "local effect reaches its colony")


func test_required_never_objective_can_win_when_held(t: T) -> void:
	var s: GameState = S1.build()
	var db: ContentDb = Content.db()
	var fixture_id: String = "audit_never_required"
	db.scenarios[fixture_id] = {"objectives": {"required": [{"id": "never", "type": "never_flag", "flag": "bad"}], "optional": []}}
	s.scenario_id = fixture_id
	Objectives.update(s, TurnResult.new())
	t.eq(s.outcome, GameState.OUTCOME_WON, "held required never objective permits victory")
	t.ok(s.objectives_done.has("never"), "held objective recorded on victory")
	var failed: GameState = S1.build()
	failed.scenario_id = fixture_id
	failed.flags["bad"] = failed.turn
	Objectives.update(failed, TurnResult.new())
	t.not_ok(failed.is_over(), "failed never objective cannot win")
	db.scenarios.erase(fixture_id)


func test_due_event_keeps_spawned_and_future_steps(t: T) -> void:
	var s: GameState = S1.build()
	var db: ContentDb = Content.db()
	var fixture_id: String = "audit_spawn_step"
	db.events[fixture_id] = {"steps": [{"step": 1, "title_key": "test.spawn", "on_fire": {"effects": [{"key": "spawn_event", "target": "labor_strike", "value": 2}]}}]}
	var due: EventInstance = EventInstance.new()
	due.chain = fixture_id
	due.step = 1
	due.empire_id = S1.PLAYER
	due.colony_id = S1.aster(s).id
	due.turn = s.turn
	var later: EventInstance = EventInstance.new()
	later.chain = "labor_strike"
	later.step = 2
	later.empire_id = S1.PLAYER
	later.turn = s.turn + 10
	s.events_scheduled.append(due)
	s.events_scheduled.append(later)
	Events._fire_due(s, s.player(), TurnResult.new())
	t.eq(s.events_scheduled.size(), 2, "preserve both spawned and existing future steps")
	var found_spawn: bool = false
	for ev: EventInstance in s.events_scheduled:
		if ev.chain == "labor_strike" and ev.turn == s.turn + 1:
			found_spawn = true
	t.ok(found_spawn, "on-fire spawned event remains scheduled for next turn")
	db.events.erase(fixture_id)


func test_survey_queue_rejects_duplicates_recovers_and_replays(t: T) -> void:
	var s: GameState = S1.build()
	var ship: Ship = S1.ship(s, "survey_probe")
	var cmd: SurveyCommand = SurveyCommand.create(S1.PLAYER, ship.id, "pl_brume")
	var base_hash: String = s.state_hash()
	var q: CommandQueue = CommandQueue.new(s)
	t.ok(q.submit(cmd).ok)
	t.eq(q.submit(cmd).reason_key, "error.ship.busy", "repeat order cannot replace active task")
	t.ne(q.undo(), null)
	t.eq(q.preview().state_hash(), base_hash, "undo restores preview")
	t.ok(q.submit(cmd).ok)
	var first: TurnResult = TurnProcessor.run(s, q.commands())
	var replay: TurnResult = TurnProcessor.run(s, q.commands())
	t.eq(first.state_hash, replay.state_hash, "same inputs produce the same result")
	t.eq(s.state_hash(), base_hash, "turn processing leaves its input untouched")
	t.eq(first.state.ships[ship.id].task_turns, 1, "task advances once")
