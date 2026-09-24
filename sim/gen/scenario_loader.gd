class_name ScenarioLoader
extends RefCounted
## Builds the starting GameState of a scenario from data/scenarios/<id>.json. Validation of the
## scenario document is DataValidator's job; this assumes a valid document.


static func build(db: ContentDb, scenario_id: String, game_seed: int, difficulty_id: String = "normal") -> GameState:
	var sc: Dictionary = db.scenarios.get(scenario_id, {})
	var s: GameState = GameState.new()
	s.game_seed = game_seed & GameState.MAX_SEED
	s.scenario_id = scenario_id
	s.difficulty_id = difficulty_id if db.has("difficulty", difficulty_id) else "normal"
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
		for t: String in e.techs:
			e.tech_turns[t] = 0
		e.legacies = DictIO.str_arr(ed, "legacies")
		e.surveyed_planets = DictIO.str_arr(ed, "surveyed")
		for sys_id: String in DictIO.str_arr(ed, "known_systems"):
			e.known_systems[sys_id] = Empire.FOG_SURVEYED
		var hands: Dictionary = DictIO.dict_of(ed, "research_hands")
		for branch: String in Empire.BRANCHES:
			var rb: ResearchBranch = e.branch(branch)
			rb.hand = DictIO.str_arr(hands, branch)
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
			if DictIO.bool_of(cd, "capital") or e.capital_id.is_empty():
				e.capital_id = c.id
			for dv: Variant in DictIO.arr_of(cd, "districts"):
				var dd: Dictionary = dv
				var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
				pd.slot = DictIO.int_of(dd, "slot")
				pd.district_id = DictIO.str_of(dd, "district")
				pd.tier = DictIO.int_of(dd, "tier", 1)
				pd.branch = DictIO.str_of(dd, "branch")
				c.districts.append(pd)
			for bv: Variant in DictIO.arr_of(cd, "buildings"):
				var bd: Dictionary = bv
				var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
				pb.slot = DictIO.int_of(bd, "slot")
				pb.building_id = DictIO.str_of(bd, "building")
				c.buildings.append(pb)
			s.colonies[c.id] = c
			if not e.surveyed_planets.has(c.planet_id):
				e.surveyed_planets.append(c.planet_id)
			if s.planets.has(c.planet_id):
				s.planets[c.planet_id].colony_id = c.id
				var sys_of: String = s.planets[c.planet_id].system_id
				if s.systems.has(sys_of) and s.systems[sys_of].owner_id.is_empty():
					s.systems[sys_of].owner_id = e.id
		for shv: Variant in DictIO.arr_of(ed, "ships"):
			var shd: Dictionary = shv
			var f: Fleet = Fleet.new()
			f.id = s.next_id("flt")
			f.owner_id = e.id
			f.system_id = DictIO.str_of(shd, "system")
			s.fleets[f.id] = f
			var sh: Ship = Ship.new()
			sh.id = s.next_id("shp")
			sh.hull = DictIO.str_of(shd, "hull")
			sh.owner_id = e.id
			sh.fleet_id = f.id
			s.ships[sh.id] = sh
			f.ship_ids.append(sh.id)
	# Starting stability comes from its sources, like every later turn.
	for cid: String in DictIO.sorted_keys(s.colonies):
		var col: Colony = s.colonies[cid]
		if not col.is_outpost() and not col.owner_id.is_empty():
			col.stability = Stability.target(s, col, Economy.colony(s, col)).total
	return s
