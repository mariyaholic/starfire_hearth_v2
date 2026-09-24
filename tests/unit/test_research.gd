extends RefCounted
## Research (§5.5, DESIGN_LOG 70, 79): costs, per-branch progress with carry-over, seeded hands,
## always-offered techs and rerolls.

const P: String = "emp_player"


func test_costs_by_tier_and_colonies(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	t.eq(Research.cost(s, e, "hydroponics").total, 8000)
	t.eq(Research.cost(s, e, "habitat_domes").total, 20000)
	t.eq(Research.cost(s, e, "jump_field_mathematics").total, 45000)
	t.eq(Research.cost(s, e, "jump_drive").total, 100000)
	var c: Colony = Colony.new()
	c.id = "col_9001"
	c.planet_id = "pl_brume"
	c.owner_id = P
	c.pops = 2
	s.colonies[c.id] = c
	s.planets["pl_brume"].colony_id = c.id
	t.eq(Research.cost(s, e, "hydroponics").total, 8400, "+5% for the second colony")


func test_start_hands_are_preseeded_without_warships(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	t.eq(e.branch("physics").hand, ["fusion_efficiency", "sensor_arrays"])
	t.eq(e.branch("society").hand, ["hydroponics", "frontier_medicine", "civic_charters"])
	t.eq(e.branch("engineering").hand, ["automated_mining", "orbital_construction"])
	for b: String in Empire.BRANCHES:
		for tid: String in Research.available(s, e, b):
			t.not_ok(DictIO.bool_of(Content.db().record("techs", tid), "military"), "%s offered in Scenario 1" % tid)


func test_progress_carries_over_and_the_hand_refills(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	e.branch("society").progress = 7950
	var r: TurnResult = S1.turn(s, [PickResearchCommand.create(P, "society", "hydroponics")])
	var e2: Empire = r.state.player()
	t.ok(e2.has_tech("hydroponics"))
	t.eq(e2.branch("society").progress, 7950 + 180 - 8000, "what is left carries over")
	t.eq(e2.branch("society").card, "")
	t.eq(e2.branch("society").hand.size(), 3)
	t.ok(e2.branch("society").hand.has("frontier_medicine"), "unpicked cards stay")
	t.ok(e2.branch("society").hand.has("civic_charters"))


func test_story_and_objective_techs_are_always_offered(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	e.techs.append("sensor_arrays")
	e.branch("physics").hand = ["fusion_efficiency"]
	Research.refill(s, e, "physics")
	t.ok(e.branch("physics").hand.has("wake_theory"), "a story tech joins the hand at once")
	e.techs.append("frontier_medicine")
	e.branch("society").hand = ["hydroponics"]
	Research.refill(s, e, "society")
	t.ok(e.branch("society").hand.has("habitat_domes"), "Scenario 1 always offers Habitat Domes")


func test_draws_are_deterministic_and_rerolls_cost_influence(t: T) -> void:
	var a: GameState = S1.build(11)
	var b: GameState = S1.build(11)
	for s: GameState in [a, b]:
		s.player().techs.append_array(["hydroponics", "frontier_medicine", "civic_charters", "colonial_administration"])
		s.player().branch("society").hand = []
		Research.refill(s, s.player(), "society")
	t.eq(a.player().branch("society").hand, b.player().branch("society").hand)
	var s2: GameState = S1.build()
	var q: CommandQueue = CommandQueue.new(s2)
	t.ok(q.submit(PickResearchCommand.create(P, "society", "civic_charters")).ok)
	t.ok(q.submit(RerollResearchCommand.create(P, "society")).ok)
	t.eq(q.preview().player().stock_of("influence"), 6000 - 2500)
	t.ok(q.preview().player().branch("society").hand.has("civic_charters"), "the picked card survives a reroll")
	t.eq(PickResearchCommand.create(P, "society", "jump_drive").validate(q.preview()).reason_key, "error.research.not_offered")


func test_wake_theory_adds_a_fragment_of_decoding(t: T) -> void:
	var s: GameState = S1.build()
	Research.grant(s, s.player(), "wake_theory")
	t.eq(s.player().decode_progress, 1000)
	t.ok(s.player().flags.has("noise_readout"))
