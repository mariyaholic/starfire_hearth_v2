extends RefCounted
## The event engine (§5.10, §13.4): scripted triggers, choices with costs and lasting effects,
## "Uncertain" outcomes, chain steps, the director's pacing, timed modifiers and the log.

const P: String = "emp_player"


func _pending(s: GameState, chain: String) -> EventInstance:
	for ev: EventInstance in s.events_pending:
		if ev.chain == chain:
			return ev
	return null


func test_labor_strike_fires_on_turn_five(t: T) -> void:
	var s: GameState = S1.build()
	var r: TurnResult = S1.advance(s, 4)
	t.eq(_pending(r.state, "labor_strike"), null, "not before turn 5")
	r = S1.advance(r.state, 1)
	var ev: EventInstance = _pending(r.state, "labor_strike")
	t.ne(ev, null, "fires in the events phase of turn 5")
	if ev != null:
		t.eq(ev.colony_id, S1.aster(r.state).id)
		t.eq(ev.cause, "scripted")
	var why: Array[WhyLog.Entry] = []
	for entry: WhyLog.Entry in r.why_log.entries:
		if entry.kind == WhyLog.KIND_EVENT_TRIGGER:
			why.append(entry)
	t.eq(why.size(), 1, "the trigger reasons are logged for Why?")


func test_choice_pays_applies_a_timed_modifier_and_schedules_the_next_step(t: T) -> void:
	var s: GameState = S1.advance(S1.build(), 5).state
	var ev: EventInstance = _pending(s, "labor_strike")
	var cmd: ChooseEventCommand = ChooseEventCommand.create(P, ev.id, 0)
	t.ok(cmd.validate(s).ok)
	var influence: int = s.player().stock_of("influence")
	cmd.apply(s)
	t.eq(s.player().stock_of("influence"), influence - 2000)
	t.eq(_pending(s, "labor_strike"), null)
	t.eq(s.modifiers.size(), 1)
	var m: Modifier = s.modifiers.values()[0]
	t.eq(m.colony_id, S1.aster(s).id)
	t.eq(m.turns_left, 10)
	t.eq(m.source_key, "event.labor_strike.1.title")
	t.eq(s.events_scheduled.size(), 1)
	t.eq(s.events_scheduled[0].step, 2)
	t.eq(s.events_scheduled[0].turn, s.turn + 8)
	var b: Breakdown = Stability.target(s, S1.aster(s), Economy.colony(s, S1.aster(s)))
	var from_event: int = 0
	for l: Breakdown.Line in b.lines:
		if l.source_key == "source.effect.event_timed":
			from_event = l.value
	t.eq(from_event, 5, "the modifier shows as one stability line named after the event")


func test_modifiers_expire(t: T) -> void:
	var s: GameState = S1.advance(S1.build(), 5).state
	var ev: EventInstance = _pending(s, "labor_strike")
	var r: TurnResult = S1.turn(s, [ChooseEventCommand.create(P, ev.id, 0)])
	t.eq(r.state.modifiers.size(), 1)
	r = S1.advance(r.state, 10)
	t.eq(r.state.modifiers.size(), 0, "a 10-turn modifier has gone")


func test_uncertain_outcomes_are_seeded(t: T) -> void:
	var outcomes: Dictionary[int, bool] = {}
	for seed_n: int in range(1, 13):
		var s: GameState = S1.build(seed_n)
		var ev: EventInstance = EventInstance.new()
		ev.id = "evt_test"
		ev.chain = "crop_blight"
		ev.step = 1
		ev.empire_id = P
		ev.colony_id = S1.aster(s).id
		ev.turn = s.turn
		s.events_pending.append(ev)
		var log: EventLogEntry = EventLogEntry.new()
		log.chain = "crop_blight"
		log.step = 1
		log.turn = s.turn
		s.event_log.append(log)
		var twin: GameState = s.clone()
		Events.choose(s, P, "evt_test", 1, null)
		Events.choose(twin, P, "evt_test", 1, null)
		t.eq(s.state_hash(), twin.state_hash(), "the same seed rolls the same outcome")
		t.ok(s.event_log[0].outcome >= 0)
		outcomes[s.event_log[0].outcome] = true
	t.eq(outcomes.size(), 2, "over a dozen seeds both outcomes occur")


func test_director_waits_and_paces(t: T) -> void:
	var s: GameState = S1.build(5)
	var emergent_turns: Array[int] = []
	var state: GameState = s
	for i in 40:
		var cmds: Array[Command] = []
		for ev: EventInstance in state.events_pending:
			cmds.append(ChooseEventCommand.create(P, ev.id, 0))
		var r: TurnResult = TurnProcessor.run(state, cmds)
		state = r.state
		for ev2: EventInstance in state.events_pending:
			if ev2.cause == "director" and ev2.turn == state.turn - 1:
				emergent_turns.append(ev2.turn)
	t.ok(not emergent_turns.is_empty(), "the director fired in 40 turns")
	for i in emergent_turns.size():
		t.ok(emergent_turns[i] >= 8, "no emergent event before the director starts")
		if i > 0:
			t.ok(emergent_turns[i] - emergent_turns[i - 1] >= Events.DIRECTOR_GAP_MIN, "at least 4 turns apart")


func test_sealed_order_grants_the_archive_and_decodes(t: T) -> void:
	var s: GameState = S1.build()
	s.turn = 40
	var r: TurnResult = S1.advance(s, 1)
	var ev: EventInstance = _pending(r.state, "sealed_order")
	t.ne(ev, null)
	t.ok(S1.aster(r.state).has_building("archive_of_sol"))
	t.ok(r.state.flags.has("sealed_order_active"))
	var er: Economy.EmpireReport = Economy.empire(r.state, P)
	t.eq(er.decode.total, Fx.mul_bp(er.research_total(), 500), "5% of all research")
	t.ok(er.decode.verify())
	r.state.player().decode_progress = 1000
	var r2: TurnResult = S1.turn(r.state, [ChooseEventCommand.create(P, ev.id, 1)])
	r2 = S1.advance(r2.state, 1)
	t.ok(r2.state.flags.has("sealed_order_fragment_1"), "the first fragment decodes once there is enough progress")


func test_event_severity_scales_emergent_losses(t: T) -> void:
	var s: GameState = S1.build(1, "story")
	var fx: Array = [{"key": "stability_add", "value": -10, "turns": 4}, {"key": "add_stock:food", "value": 5000}]
	var out: Array = Events.scaled(s, fx, "solar_flare")
	t.eq(int(out[0]["value"]), -5, "Story halves emergent losses")
	t.eq(int(out[1]["value"]), 5000, "gains are not scaled")
	t.eq(int(Events.scaled(s, fx, "labor_strike")[0]["value"]), -10, "scripted story steps keep their numbers")
