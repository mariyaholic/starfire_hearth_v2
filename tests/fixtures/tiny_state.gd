class_name TinyState
extends RefCounted
## A small hand-built state for unit tests that must not depend on data files.


static func build(game_seed: int = 1234) -> GameState:
	var s: GameState = GameState.new()
	s.game_seed = game_seed
	s.scenario_id = "test"

	var player: Empire = Empire.new()
	player.id = "emp_player"
	player.faction_id = "ark"
	player.origin_id = "generation_ark"
	player.is_player = true
	player.name_key = "faction.ark.name"
	player.stock = {"food": 15000, "energy": 12000, "minerals": 25000, "alloys": 0, "influence": 6000}
	player.techs = ["hydroponics"]
	player.known_systems = {"sys_ember": Empire.FOG_SURVEYED}
	s.empires[player.id] = player
	s.player_id = player.id

	var other: Empire = Empire.new()
	other.id = "emp_meridian"
	other.faction_id = "meridian"
	other.name_key = "faction.meridian.name"
	other.stock = {"food": 5000, "energy": 5000}
	s.empires[other.id] = other

	var ember: StarSystem = StarSystem.new()
	ember.id = "sys_ember"
	ember.name_key = "system.ember.name"
	ember.spectral = "K"
	ember.owner_id = player.id
	s.systems[ember.id] = ember
	var tessel: StarSystem = StarSystem.new()
	tessel.id = "sys_tessel"
	tessel.name_key = "system.tessel.name"
	tessel.x = 300
	tessel.y = -150
	tessel.specials = ["rich_asteroids"]
	s.systems[tessel.id] = tessel

	var lane: Lane = Lane.new()
	lane.id = "lane_0001"
	lane.a = ember.id
	lane.b = tessel.id
	lane.length_cly = 350
	s.lanes[lane.id] = lane

	var aster: Planet = Planet.new()
	aster.id = "pl_aster"
	aster.system_id = ember.id
	aster.name_key = "planet.aster.name"
	aster.type = "continental"
	aster.size = "medium"
	aster.traits = ["fertile_soil"]
	aster.blocked_slots = [4, 11]
	s.planets[aster.id] = aster
	ember.planet_ids.append(aster.id)
	var brume: Planet = Planet.new()
	brume.id = "pl_brume"
	brume.system_id = ember.id
	brume.name_key = "planet.brume.name"
	brume.type = "ocean"
	brume.size = "small"
	brume.orbit = 1
	s.planets[brume.id] = brume
	ember.planet_ids.append(brume.id)

	var col: Colony = Colony.new()
	col.id = s.next_id("col")
	col.planet_id = aster.id
	col.owner_id = player.id
	col.pops = 10
	col.stability = 60
	var d1: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
	d1.slot = 0
	d1.district_id = "agriculture"
	col.districts.append(d1)
	var b1: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
	b1.slot = 1
	b1.building_id = "ark_hull"
	col.buildings.append(b1)
	s.colonies[col.id] = col
	aster.colony_id = col.id

	var design: Design = Design.new()
	design.id = s.next_id("des")
	design.owner_id = player.id
	design.hull = "corvette"
	design.modules = ["mass_driver", "mass_driver", ""]
	s.designs[design.id] = design

	var fleet: Fleet = Fleet.new()
	fleet.id = s.next_id("flt")
	fleet.owner_id = player.id
	fleet.system_id = ember.id
	s.fleets[fleet.id] = fleet
	for i in 2:
		var ship: Ship = Ship.new()
		ship.id = s.next_id("shp")
		ship.design_id = design.id
		ship.owner_id = player.id
		ship.fleet_id = fleet.id
		ship.structure = 15000
		s.ships[ship.id] = ship
		fleet.ship_ids.append(ship.id)
	return s
