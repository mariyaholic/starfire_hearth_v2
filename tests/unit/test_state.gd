extends RefCounted
## GameState serialisation, cloning, ids and invariants.


func test_round_trip_is_identical(t: T) -> void:
	var s: GameState = TinyState.build()
	var text: String = CanonicalJson.stringify(s.to_dict())
	t.ne(text, "", "state serialises")
	var back: GameState = GameState.from_dict(CanonicalJson.parse(text))
	t.eq(CanonicalJson.stringify(back.to_dict()), text)
	t.eq(back.state_hash(), s.state_hash())


func test_round_trip_keeps_types(t: T) -> void:
	var back: GameState = GameState.from_dict(CanonicalJson.parse(CanonicalJson.stringify(TinyState.build().to_dict())))
	var col: Colony = back.colonies["col_0001"]
	t.eq(typeof(col.pops), TYPE_INT)
	t.eq(col.districts[0].district_id, "agriculture")
	t.eq(col.buildings[0].building_id, "ark_hull")
	t.eq(back.planets["pl_aster"].blocked_slots, [4, 11])
	t.eq(back.empires["emp_player"].stock["food"], 15000)
	t.eq(back.player().id, "emp_player")


func test_clone_is_deep(t: T) -> void:
	var s: GameState = TinyState.build()
	var c: GameState = s.clone()
	c.colonies["col_0001"].pops = 99
	c.empires["emp_player"].stock["food"] = 1
	c.planets["pl_aster"].traits.append("rich_veins")
	t.eq(s.colonies["col_0001"].pops, 10)
	t.eq(s.empires["emp_player"].stock["food"], 15000)
	t.eq(s.planets["pl_aster"].traits, ["fertile_soil"])


func test_next_id_is_zero_padded_and_monotonic(t: T) -> void:
	var s: GameState = GameState.new()
	t.eq(s.next_id("col"), "col_0001")
	t.eq(s.next_id("col"), "col_0002")
	t.eq(s.next_id("flt"), "flt_0001")


func test_hash_changes_with_state(t: T) -> void:
	var s: GameState = TinyState.build()
	var h: String = s.state_hash()
	t.eq(h.length(), 64)
	s.colonies["col_0001"].pops += 1
	t.ne(s.state_hash(), h)


func test_float_in_state_breaks_the_hash(t: T) -> void:
	var s: GameState = TinyState.build()
	var d: Dictionary = s.to_dict()
	d["empires"]["emp_player"]["stock"]["food"] = 1.5
	var errors: Array[String] = []
	CanonicalJson.stringify(d, errors)
	t.eq(errors.size(), 1)


func test_invariants_hold_for_fixture(t: T) -> void:
	t.empty(Invariants.check(TinyState.build()))


func test_invariants_catch_broken_references(t: T) -> void:
	var s: GameState = TinyState.build()
	s.colonies["col_0001"].planet_id = "pl_nowhere"
	s.fleets["flt_0001"].ship_ids.append("shp_9999")
	s.empires["emp_player"].stock["energy"] = -5
	s.colonies["col_0001"].stability = 140
	var problems: Array[String] = Invariants.check(s)
	t.eq(problems.size(), 4, str(problems))


func test_invariants_catch_double_booked_slot(t: T) -> void:
	var s: GameState = TinyState.build()
	var d: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
	d.slot = 1
	d.district_id = "mining"
	s.colonies["col_0001"].districts.append(d)
	t.eq(Invariants.check(s).size(), 1)
