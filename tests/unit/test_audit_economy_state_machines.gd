extends RefCounted

const P: String = "emp_player"


func test_reroll_all_protected_cards_is_rejected_without_spending(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	# Both special offers are reachable after researching their prerequisite chains.
	e.techs.append_array(["frontier_medicine", "civic_charters", "cultural_archive"])
	var rb: ResearchBranch = e.branch("society")
	rb.hand = ["habitat_domes", "xenolinguistics", "hydroponics"]
	rb.card = "hydroponics"
	t.ok(Research.available(s, e, "society").has("colonial_administration"))
	var q: CommandQueue = CommandQueue.new(s)
	var result: Result = q.submit(RerollResearchCommand.create(P, "society"))
	t.eq(result.reason_key, "error.research.nothing_new")
	t.eq(q.preview().player().stock_of("influence"), e.stock_of("influence"))
	t.eq(q.preview().player().branch("society").hand, rb.hand)
	# Switching to a protected card releases a slot; a reroll then succeeds and is undoable.
	t.ok(q.submit(PickResearchCommand.create(P, "society", "xenolinguistics")).ok)
	t.ok(q.submit(RerollResearchCommand.create(P, "society")).ok)
	var after: ResearchBranch = q.preview().player().branch("society")
	t.ok(after.hand.has("habitat_domes"))
	t.ok(after.hand.has("xenolinguistics"))
	t.ok(after.hand.has("colonial_administration"))
	t.not_ok(after.hand.has("hydroponics"))
	t.eq(q.preview().player().stock_of("influence"), e.stock_of("influence") - Research.REROLL_COST)
	q.undo()
	t.eq(q.preview().player().branch("society").hand, rb.hand)
	t.eq(q.preview().player().stock_of("influence"), e.stock_of("influence"))
