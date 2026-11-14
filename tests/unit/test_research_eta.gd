extends RefCounted
## ETA reports the next actual research phase rather than zero turns for banked points.


func test_bank_without_card_and_invalid_inputs(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	var rb: ResearchBranch = e.branch("physics")
	rb.card = ""
	rb.progress = 3800
	var before: String = s.state_hash()
	var bank: Breakdown = Research.stored_progress(s, e.id, "physics")
	t.eq(bank.total, 3800)
	t.ok(bank.verify())
	t.eq(Research.turns_remaining(s, e.id, "physics"), Research.ETA_NO_CARD)
	t.not_ok(Research.card_funded(s, e.id, "physics"))
	t.eq(Research.turns_remaining(s, "missing", "physics"), Research.ETA_INVALID)
	t.eq(Research.turns_remaining(s, e.id, "bad_branch"), Research.ETA_INVALID)
	t.eq(s.state_hash(), before)


func test_banked_active_card_finishes_next_research_phase(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	var rb: ResearchBranch = e.branch("physics")
	var card: String = rb.hand[0]
	rb.card = card
	rb.progress = Research.cost(s, e, card).total + 1200
	t.eq(Research.turns_remaining(s, e.id, "physics"), 1)
	t.ok(Research.card_funded(s, e.id, "physics"))
	t.not_ok(e.has_tech(card))
	var after: TurnResult = TurnProcessor.run(s, [] as Array[Command])
	t.ok(after.state.player().has_tech(card))
	t.eq(after.state.player().branch("physics").card, "")
	t.ok(after.state.player().branch("physics").progress >= 1200)


func test_zero_income_distinguishes_funded_and_unfunded(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	# Removing the capital gives no research income; call the research phase directly so the
	# scenario's loss check cannot mask the phase behavior.
	s.colonies.erase(e.capital_id)
	e.capital_id = ""
	var rb: ResearchBranch = e.branch("physics")
	var card: String = rb.hand[0]
	rb.card = card
	rb.progress = 0
	t.eq(Economy.empire(s, e.id).research["physics"].total, 0)
	t.eq(Research.turns_remaining(s, e.id, "physics"), Research.ETA_NO_INCOME)
	t.not_ok(Research.card_funded(s, e.id, "physics"))
	rb.progress = Research.cost(s, e, card).total
	t.eq(Research.turns_remaining(s, e.id, "physics"), 1)
	var report: Economy.EmpireReport = Economy.empire(s, e.id)
	Research.update(s, e, report, TurnResult.new())
	t.ok(e.has_tech(card))
	t.eq(rb.card, "")


func test_positive_income_rounds_up_and_invalid_card_fails_closed(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	var rb: ResearchBranch = e.branch("physics")
	rb.card = rb.hand[0]
	var cost: int = Research.cost(s, e, rb.card).total
	var rate: int = Economy.empire(s, e.id).research["physics"].total
	t.ok(rate > 0)
	rb.progress = cost - rate - 1
	t.eq(Research.turns_remaining(s, e.id, "physics"), 2)
	rb.card = "not_a_technology"
	t.eq(Research.turns_remaining(s, e.id, "physics"), Research.ETA_INVALID)
