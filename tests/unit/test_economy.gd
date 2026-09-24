extends RefCounted
## Jobs, output, upkeep, housing and caps on the Scenario 1 start state, against §5.3 and §5.4.


func test_aster_start_matches_section_5(t: T) -> void:
	var s: GameState = S1.build()
	var er: Economy.EmpireReport = Economy.empire(s, S1.PLAYER)
	var cr: Economy.ColonyReport = er.colonies[S1.aster(s).id]
	t.eq(cr.housing.total, 20, "2 Habitation x 6, 4 other districts x 1, Ark Hull 4")
	t.eq(cr.jobs_total, 10)
	t.eq(cr.unemployed, 0)
	# Food: 4 farmers x 4.00 = 16.00, +20% Fertile Soil and +5% each for the two touching farms,
	# +3.00 Ark Hull, -10.00 for 10k settlers.
	t.eq(er.net_of("food"), 1300)
	# Energy: 2 technicians 10.00 + 2 clerks 4.00 + Ark Hull 3.00 - district upkeep 3.50 -
	# Spaceport 2.00 - ships 1.50.
	t.eq(er.net_of("energy"), 1000)
	t.eq(er.net_of("minerals"), 1100, "2 miners 8.00 + Ark Hull 3.00")
	t.eq(er.net_of("alloys"), 0)
	t.eq(er.net_of("influence"), 400, "+3.00 base, +1.00 for a colony at stability 60 or more")
	for b: String in Empire.BRANCHES:
		t.eq(er.research[b].total, 180, "capital 2.00, -10%% Generation Ark (%s)" % b)
	t.eq(er.cap_of("food"), 50000)
	t.eq(er.cap_of("alloys"), 25000)
	t.ok(S1.all_verify(er), "every breakdown sums to its total")


func test_start_stability_is_67(t: T) -> void:
	var s: GameState = S1.build()
	var c: Colony = S1.aster(s)
	t.eq(c.stability, 67, "base 50, 2 clerks, Ark Hull 5, origin 10")
	var b: Breakdown = Stability.target(s, c, Economy.colony(s, c))
	t.eq(b.total, 67)
	t.ok(b.verify())


func test_jobs_fill_by_priority_and_idle_settlers_cost_stability(t: T) -> void:
	var s: GameState = S1.build()
	var c: Colony = S1.aster(s)
	c.pops = 7
	var order: Array[String] = ["research", "clerks", "minerals", "energy", "food", "alloys"]
	c.job_priority = order
	var cr: Economy.ColonyReport = Economy.colony(s, c)
	t.eq(cr.filled_by_group.get("clerks", 0), 2)
	t.eq(cr.filled_by_group.get("minerals", 0), 2)
	t.eq(cr.filled_by_group.get("energy", 0), 2)
	t.eq(cr.filled_by_group.get("food", 0), 1, "farms get only what is left")
	c.pops = 13
	cr = Economy.colony(s, c)
	t.eq(cr.unemployed, 3)
	var st: Breakdown = Stability.target(s, c, cr)
	var idle: int = 0
	for l: Breakdown.Line in st.lines:
		if l.source_key == "source.unemployed":
			idle = l.value
	t.eq(idle, -9, "-3 for each thousand without work")


func test_homeless_settlers_cost_8_and_halve_growth(t: T) -> void:
	var s: GameState = S1.build()
	var c: Colony = S1.aster(s)
	c.pops = 22
	var cr: Economy.ColonyReport = Economy.colony(s, c)
	t.eq(cr.homeless, 2)
	var st: Breakdown = Stability.target(s, c, cr)
	var homeless: int = 0
	for l: Breakdown.Line in st.lines:
		if l.source_key == "source.homeless":
			homeless = l.value
	t.eq(homeless, -16)
	var g: Breakdown = Population.growth(s, c, cr, 100, 100)
	t.eq(g.total, 500, "10.00 base, -50% while homeless")


func test_upkeep_is_not_scaled_by_bonuses(t: T) -> void:
	var s: GameState = S1.build()
	s.player().techs.append("fusion_efficiency")
	var er: Economy.EmpireReport = Economy.empire(s, S1.PLAYER)
	# +10% energy applies to the 17.00 produced on Aster, not to its upkeep.
	t.eq(er.net_of("energy"), 1000 + 170)
	t.ok(S1.all_verify(er))


func test_industry_slows_when_minerals_run_short(t: T) -> void:
	var s: GameState = S1.build()
	var c: Colony = S1.aster(s)
	var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
	pd.slot = 8
	pd.district_id = "industry"
	c.districts.append(pd)
	c.pops = 12
	s.player().stock["minerals"] = 0
	var er: Economy.EmpireReport = Economy.empire(s, S1.PLAYER)
	# Mining 8.00 + Ark 3.00 against 12.00 wanted: industry runs at 91%.
	t.eq(er.net_of("minerals"), 0, "minerals never go negative")
	t.eq(er.industry_bp, 9166)
	t.ok(er.net_of("alloys") < 600 and er.net_of("alloys") > 500)
	t.ok(S1.all_verify(er))


func test_caps_clamp_stock_and_report_overflow(t: T) -> void:
	var s: GameState = S1.build()
	s.player().stock["food"] = 49900
	var r: TurnResult = S1.advance(s, 1)
	t.eq(r.state.player().stock_of("food"), 50000)
	var found: bool = false
	for it: ReportItem in r.report_items:
		if it.text_key == "report.overflow":
			found = true
			t.eq(it.args["lost_c"], 1200)
	t.ok(found, "the overflow is reported")


func test_energy_shortfall_clamps_and_costs_stability(t: T) -> void:
	var s: GameState = S1.build()
	s.player().stock["energy"] = 0
	for i in 6:
		var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
		pd.slot = 8 + i
		pd.district_id = "research"
		pd.branch = "physics"
		S1.aster(s).districts.append(pd)
	var r: TurnResult = S1.advance(s, 1)
	t.eq(r.state.player().stock_of("energy"), 0)
	t.eq(r.state.player().energy_short_turns, 1)
	var b: Breakdown = Stability.target(r.state, S1.aster(r.state), Economy.colony(r.state, S1.aster(r.state)))
	var short: int = 0
	for l: Breakdown.Line in b.lines:
		if l.source_key == "source.energy_short":
			short = l.value
	t.eq(short, -10)


func test_hex_grid_is_symmetric_and_centred(t: T) -> void:
	for n: int in [6, 8, 12, 16, 20, 25, 30]:
		var cs: Array[Vector2i] = HexGrid.coords(n)
		t.eq(cs.size(), n)
		t.eq(cs[0], Vector2i.ZERO)
		var unique: Dictionary[Vector2i, bool] = {}
		for c: Vector2i in cs:
			unique[c] = true
		t.eq(unique.size(), n, "no two slots share a hex (%d)" % n)
		for a in n:
			for b: int in HexGrid.neighbours(a, n):
				t.ok(HexGrid.neighbours(b, n).has(a), "adjacency is symmetric (%d: %d-%d)" % [n, a, b])
	t.eq(HexGrid.neighbours(0, 20), [1, 2, 3, 4, 5, 6])


func test_dome_world_has_half_its_slots(t: T) -> void:
	var s: GameState = S1.build()
	t.eq(ColonyRules.slot_count(s.planets["pl_cinder"]), 8, "small 16, halved on a dome world")
	t.eq(ColonyRules.slot_count(s.planets["pl_brume"]), 16)
	t.eq(ColonyRules.slot_count(s.planets["pl_dross"]), 0)
