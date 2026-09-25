extends RefCounted
## Civilian ships (DESIGN_LOG 59–61, 77), ordinances (§5.11), the market (§5.3, DESIGN_LOG 78) and
## governors (DESIGN_LOG 71, 80).

const P: String = "emp_player"


func test_survey_takes_two_turns(t: T) -> void:
	var s: GameState = S1.build()
	var probe: Ship = S1.ship(s, "survey_probe")
	t.eq(ColoniseCommand.create(P, probe.id, "pl_brume").validate(s).reason_key, "error.ship.wrong_role")
	var r: TurnResult = S1.turn(s, [SurveyCommand.create(P, probe.id, "pl_brume")])
	t.not_ok(r.state.player().surveyed_planets.has("pl_brume"))
	r = S1.advance(r.state, 1)
	t.ok(r.state.player().surveyed_planets.has("pl_brume"))
	t.eq(SurveyCommand.create(P, probe.id, "pl_brume").validate(r.state).reason_key, "error.planet.already_surveyed")


func test_outpost_costs_influence_and_builds_in_four_turns(t: T) -> void:
	var s: GameState = S1.build()
	s.player().stock["influence"] = 6000
	var cship: Ship = S1.ship(s, "construction_ship")
	t.eq(BuildOutpostCommand.create(P, cship.id, "pl_tithe", "minerals").validate(s).reason_key, "error.planet.not_surveyed")
	s.player().surveyed_planets.append("pl_tithe")
	t.eq(BuildOutpostCommand.create(P, cship.id, "pl_tithe", "energy").validate(s).reason_key, "error.outpost.wrong_kind")
	var r: TurnResult = S1.turn(s, [BuildOutpostCommand.create(P, cship.id, "pl_tithe", "minerals")])
	t.eq(r.state.player().stock_of("influence"), 6000 - 5000 + 400)
	r = S1.advance(r.state, 3)
	var outposts: Array[Colony] = ColonyRules.outposts(r.state, P)
	t.eq(outposts.size(), 1)
	var er: Economy.EmpireReport = Economy.empire(r.state, P)
	t.eq(er.colonies[outposts[0].id].net_of("minerals"), 600)
	t.eq(er.colonies[outposts[0].id].net_of("energy"), -50)


func test_outpost_discounts_stop_at_75_percent(t: T) -> void:
	var s: GameState = S1.build()
	var e: Empire = s.player()
	e.techs.append("colonial_administration")
	e.ordinances["frontier_charter"] = -1
	var b: Breakdown = Ships.outpost_cost(s, e)
	t.eq(b.total, 1250)
	t.eq(b.note_key, "note.outpost_cost_floor")
	t.ok(b.verify())


func test_colony_ship_founds_a_colony_with_its_first_shelter(t: T) -> void:
	var s: GameState = S1.build()
	s.player().surveyed_planets.append("pl_brume")
	var ship: Ship = Ships.launch(s, S1.aster(s), "colony_ship")
	var r: TurnResult = S1.turn(s, [ColoniseCommand.create(P, ship.id, "pl_brume")])
	var brume: Colony = r.state.colonies.get(r.state.planets["pl_brume"].colony_id, null)
	t.ne(brume, null)
	if brume != null:
		t.eq(brume.pops, 2)
		t.eq(brume.districts.size(), 1)
		t.eq(brume.districts[0].district_id, "habitation")
		t.eq(Economy.colony(r.state, brume).housing.total, 4, "6 housing at 80% habitability, rounded down")
	t.eq(r.state.ships.has(ship.id), false, "the ship is used up")
	var cinder_ship: Ship = Ships.launch(r.state, S1.aster(r.state), "colony_ship")
	r.state.player().surveyed_planets.append("pl_cinder")
	t.eq(ColoniseCommand.create(P, cinder_ship.id, "pl_cinder").validate(r.state).reason_key, "error.colony.needs_domes")


func test_ordinances_slots_duration_and_lock(t: T) -> void:
	var s: GameState = S1.build()
	s.player().stock["influence"] = 6000
	var q: CommandQueue = CommandQueue.new(s)
	t.eq(q.submit(ActivateOrdinanceCommand.create(P, "radio_silence")).reason_key, "error.ordinance.locked")
	t.ok(q.submit(ActivateOrdinanceCommand.create(P, "festival")).ok)
	t.eq(q.preview().player().stock_of("influence"), 3000)
	t.eq(q.submit(ActivateOrdinanceCommand.create(P, "festival")).reason_key, "error.ordinance.active")
	var r: TurnResult = S1.turn(s, q.commands())
	t.eq(r.state.player().ordinances["festival"], 9)
	t.eq(S1.aster(r.state).stability, 77, "+10 from the Festival")
	r = S1.advance(r.state, 9)
	t.not_ok(r.state.player().ordinances.has("festival"), "a 10-turn ordinance ends by itself")
	var s2: GameState = S1.build()
	s2.player().stock["influence"] = 20000
	var q2: CommandQueue = CommandQueue.new(s2)
	t.ok(q2.submit(ActivateOrdinanceCommand.create(P, "festival")).ok)
	t.ok(q2.submit(ActivateOrdinanceCommand.create(P, "research_grants")).ok)
	t.eq(q2.submit(ActivateOrdinanceCommand.create(P, "work_drive")).reason_key, "error.ordinance.no_slot")


func test_market_needs_an_exchange_and_uses_fixed_rates(t: T) -> void:
	var s: GameState = S1.build()
	s.player().stock["food"] = 15000
	t.eq(TradeCommand.create(P, "food", 1, false).validate(s).reason_key, "error.market.closed")
	var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
	pb.slot = 8
	pb.building_id = "market_exchange"
	S1.aster(s).buildings.append(pb)
	t.eq(TradeCommand.create(P, "influence", 1, true).validate(s).reason_key, "error.market.not_traded")
	TradeCommand.create(P, "alloys", 1, true).apply(s)
	t.eq(s.player().stock_of("alloys"), 1000)
	t.eq(s.player().stock_of("energy"), 12000 - 6000, "10 metals at 6.00")
	TradeCommand.create(P, "food", 2, false).apply(s)
	t.eq(s.player().stock_of("food"), 15000 - 2000)
	t.eq(s.player().stock_of("energy"), 6000 + 2000, "20 food at 1.00")


func test_governor_saves_from_income_and_builds_from_its_purse(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	var r: TurnResult = S1.turn(s, [SetGovernorCommand.create(P, cid, true, "balanced", 5000)])
	var c: Colony = S1.aster(r.state)
	t.eq(c.governor_funds, 550, "half of the 11.00 minerals income")
	t.eq(r.state.player().stock_of("minerals"), 25000 + 550, "the other half reached the stock")
	var er: Economy.EmpireReport = Economy.empire(r.state, S1.PLAYER)
	t.eq(Governor.allowance(c, er), 550)
	var plan: Advisor.Option = Governor.plan(r.state, c, er)
	t.ne(plan, null)
	if plan != null:
		t.ok(not plan.reason_key.is_empty())
		var q: CommandQueue = CommandQueue.new(r.state)
		t.ok(q.submit(VetoPlanCommand.create(P, cid, plan.veto_key())).ok)
		var after: Advisor.Option = Governor.plan(q.preview(), q.preview().colonies[cid], er)
		t.ok(after == null or after.veto_key() != plan.veto_key(), "a vetoed plan is skipped")
	var off: TurnResult = S1.turn(r.state, [SetGovernorCommand.create(P, cid, false)])
	t.eq(S1.aster(off.state).governor_funds, 0, "turning the governor off returns its purse")
