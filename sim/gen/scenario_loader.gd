class_name ScenarioLoader
extends RefCounted
## Builds the starting GameState of a scenario from data/scenarios/<id>.json. Validation of the
## scenario document is DataValidator's job; this assumes a valid document.


static func build(db: ContentDb, scenario_id: String, game_seed: int) -> GameState:
	var sc: Dictionary = db.scenarios.get(scenario_id, {})
	var s: GameState = GameState.new()
	s.game_seed = game_seed & GameState.MAX_SEED
	s.scenario_id = scenario_id
	var map: Dictionary = DictIO.dict_of(sc, "map")
	for sv: Variant in DictIO.arr_of(map, "systems"):
		var sd: Dictionary = sv
		var sys: StarSystem = StarSystem.new()
		sys.id = DictIO.str_of(sd, "id")
		sys.name_key = DictIO.str_of(sd, "name_key")
		sys.x = DictIO.int_of(sd, "x")
		sys.y = DictIO.int_of(sd, "y")
		sys.spectral = DictIO.str_of(sd, "spectral", "G")
		sys.magnitude = DictIO.int_of(sd, "magnitude", 3)
		sys.specials = DictIO.str_arr(sd, "specials")
		sys.beacon = DictIO.str_of(sd, "beacon", StarSystem.BEACON_NONE)
		for pv: Variant in DictIO.arr_of(sd, "planets"):
			var pd: Dictionary = pv
			var p: Planet = Planet.new()
			p.id = DictIO.str_of(pd, "id")
			p.system_id = sys.id
			p.name_key = DictIO.str_of(pd, "name_key")
			p.type = DictIO.str_of(pd, "type")
			p.size = DictIO.str_of(pd, "size")
			p.orbit = DictIO.int_of(pd, "orbit")
			p.traits = DictIO.str_arr(pd, "traits")
			p.blocked_slots = DictIO.int_arr(pd, "blocked_slots")
			p.art_seed = DictIO.int_of(pd, "art_seed")
			s.planets[p.id] = p
			sys.planet_ids.append(p.id)
		s.systems[sys.id] = sys
	for lv: Variant in DictIO.arr_of(map, "lanes"):
		var ld: Dictionary = lv
		var lane: Lane = Lane.new()
		lane.id = s.next_id("lane")
		lane.a = DictIO.str_of(ld, "a")
		lane.b = DictIO.str_of(ld, "b")
		lane.length_cly = DictIO.int_of(ld, "length_cly", 100)
		lane.kind = DictIO.str_of(ld, "kind", Lane.KIND_DEEP)
		s.lanes[lane.id] = lane
	for f: String in DictIO.str_arr(map, "fog_locked"):
		s.flags["fog_locked:" + f] = 1

	var start: Dictionary = DictIO.dict_of(sc, "start")
	for ev: Variant in DictIO.arr_of(start, "empires"):
		var ed: Dictionary = ev
		var e: Empire = Empire.new()
		e.id = DictIO.str_of(ed, "id")
		e.faction_id = DictIO.str_of(ed, "faction")
		e.origin_id = DictIO.str_of(ed, "origin")
		e.is_player = DictIO.bool_of(ed, "is_player")
		e.name_key = DictIO.str_of(db.record("factions", e.faction_id), "name_key")
		e.stock = DictIO.int_map(ed, "stock")
		e.techs = DictIO.str_arr(ed, "techs")
		for sys_id: String in DictIO.str_arr(ed, "known_systems"):
			e.known_systems[sys_id] = Empire.FOG_SURVEYED
		s.empires[e.id] = e
		if e.is_player:
			s.player_id = e.id
		for cv: Variant in DictIO.arr_of(ed, "colonies"):
			var cd: Dictionary = cv
			var c: Colony = Colony.new()
			c.id = s.next_id("col")
			c.planet_id = DictIO.str_of(cd, "planet")
			c.owner_id = e.id
			c.pops = DictIO.int_of(cd, "pops")
			c.stability = DictIO.int_of(cd, "stability", 50)
			for dv: Variant in DictIO.arr_of(cd, "districts"):
				var dd: Dictionary = dv
				var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
				pd.slot = DictIO.int_of(dd, "slot")
				pd.district_id = DictIO.str_of(dd, "district")
				pd.tier = DictIO.int_of(dd, "tier", 1)
				c.districts.append(pd)
			for bv: Variant in DictIO.arr_of(cd, "buildings"):
				var bd: Dictionary = bv
				var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
				pb.slot = DictIO.int_of(bd, "slot")
				pb.building_id = DictIO.str_of(bd, "building")
				c.buildings.append(pb)
			s.colonies[c.id] = c
			if s.planets.has(c.planet_id):
				s.planets[c.planet_id].colony_id = c.id
				var sys_of: String = s.planets[c.planet_id].system_id
				if s.systems.has(sys_of) and s.systems[sys_of].owner_id.is_empty():
					s.systems[sys_of].owner_id = e.id
	return s
