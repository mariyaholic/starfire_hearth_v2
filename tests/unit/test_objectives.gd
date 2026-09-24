extends RefCounted
## Scenario objectives, victory and loss (§5.12, §10.2).


func test_statuses_count_progress(t: T) -> void:
	var s: GameState = S1.build()
	var by_id: Dictionary[String, Objectives.Status] = {}
	for st: Objectives.Status in Objectives.statuses(s):
		by_id[st.id] = st
	t.eq(by_id["develop_3"].progress, 1, "Aster starts developed")
	t.eq(by_id["develop_3"].target, 3)
	t.eq(by_id["outpost_1"].progress, 0)
	t.eq(by_id["pops_40"].progress, 10)
	t.not_ok(by_id["never_starve"].failed)
	t.ok(by_id["develop_3"].required)
	t.not_ok(by_id["pops_40"].required)


func test_stability_streak_needs_two_colonies(t: T) -> void:
	var s: GameState = S1.build()
	var r: TurnResult = S1.advance(s, 12)
	t.eq(r.state.objective_progress.get("stable_10", 0), 0, "one colony does not count")
	t.not_ok(r.state.objectives_done.has("stable_10"))


func test_losing_the_capital_loses_the_scenario(t: T) -> void:
	var s: GameState = S1.build()
	S1.aster(s).pops = 0
	var r: TurnResult = S1.advance(s, 1)
	t.eq(r.state.outcome, GameState.OUTCOME_LOST)
	t.eq(r.state.outcome_reason, "outcome.capital_empty")


func test_all_required_objectives_win(t: T) -> void:
	var s: GameState = S1.build()
	for id: String in ["develop_3", "outpost_1", "stable_10", "sealed_order_1"]:
		s.objectives_done[id] = 1
	var r: TurnResult = S1.advance(s, 1)
	t.eq(r.state.outcome, GameState.OUTCOME_WON)
	t.ok(r.state.objectives_done.has("never_starve"), "a 'never' objective that held completes at victory")


func test_tutorial_conditions(t: T) -> void:
	var s: GameState = S1.build()
	t.eq(DictIO.str_of(Tutorial.current(s), "id"), "t_report")
	var q: CommandQueue = CommandQueue.new(s)
	q.submit(PlaceDistrictCommand.create(S1.PLAYER, S1.aster(s).id, 8, "agriculture"))
	t.ok(Tutorial.condition_met(q.preview(), S1.PLAYER, "queued_district:agriculture"))
	t.not_ok(Tutorial.condition_met(q.preview(), S1.PLAYER, "queued_district:industry"))
	t.ok(q.submit(AcknowledgeCommand.create(S1.PLAYER, "t_report")).ok)
	t.eq(q.submit(AcknowledgeCommand.create(S1.PLAYER, "t_report")).reason_key, "error.tutorial.already_done")
	t.eq(DictIO.str_of(Tutorial.current(q.preview()), "id"), "t_food")
