class_name M1VisualSnapshot
extends RefCounted
## A detached presentation description. Renderers never receive mutable simulation objects.
## M1 supplies known systems and surveyed planets, but no foreign-colony memory snapshots.
## Consequently only owned colonies and ships are included in the incorporation study.

static func system_view(state: GameState, system_id: String) -> Dictionary:
	if state == null or not state.systems.has(system_id): return {}
	var viewer: Empire = state.player()
	if viewer == null or not viewer.known_systems.has(system_id): return {}
	var system: StarSystem = state.systems[system_id]
	var planets: Array[Dictionary] = []
	for id: String in system.planet_ids:
		var planet: Planet = state.planets[id]
		var known: bool = viewer.surveyed_planets.has(id)
		var description: Dictionary = {"id": id, "name_key": planet.name_key,
			"kind": planet.type, "seed": planet.art_seed, "orbit": planet.orbit, "surveyed": known}
		# Physical appearance follows the same disclosure as M1's planet tiles.
		# Site layout, traits, and settlement content require additional permission.
		if known:
			description["traits"] = planet.traits.duplicate()
			description["slot_count"] = ColonyRules.slot_count(planet)
			description["blocked"] = planet.blocked_slots.duplicate()
		planets.append(description)
	planets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["orbit"] < b["orbit"])
	var ships: Array[Dictionary] = []
	for ship: Ship in state.ships_of(viewer.id):
		if Ships.system_of(state, ship) != system_id: continue
		ships.append({"id": ship.id, "name_key": DictIO.str_of(Content.db().record("hulls", ship.hull), "name_key"),
			"hull": ship.hull, "target": ship.task_target, "task": ship.task, "turns_left": ship.task_turns})
	ships.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var outposts: Array[Dictionary] = []
	var colonies: Array[Dictionary] = []
	for colony: Colony in state.colonies_of(viewer.id):
		var planet: Planet = state.planets[colony.planet_id]
		if planet.system_id != system_id: continue
		var place: Dictionary = {"id": colony.id, "planet": planet.id, "name_key": planet.name_key}
		if colony.is_outpost():
			place["resource"] = colony.outpost_kind
			outposts.append(place)
		else: colonies.append(place)
	outposts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	colonies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return {"id": system.id, "name_key": system.name_key, "spectral": system.spectral,
		"seed": Rng.salt_of("system_surface:" + system.id), "planets": planets, "ships": ships,
		"outposts": outposts, "colonies": colonies}


static func colony_view(state: GameState, colony_id: String) -> Dictionary:
	if state == null or not state.colonies.has(colony_id): return {}
	var colony: Colony = state.colonies[colony_id]
	if colony.owner_id != state.player_id or colony.is_outpost(): return {}
	var planet: Planet = state.planets[colony.planet_id]
	if not state.player().known_systems.has(planet.system_id): return {}
	var districts: Array[Dictionary] = []
	for district: Colony.PlacedDistrict in colony.districts:
		districts.append({"slot": district.slot, "district": district.district_id, "tier": district.tier})
	var buildings: Array[Dictionary] = []
	for building: Colony.PlacedBuilding in colony.buildings:
		buildings.append({"slot": building.slot, "id": building.building_id})
	var queue: Array[Dictionary] = []
	for item: BuildItem in colony.queue:
		if item.kind == BuildItem.KIND_SHIP: continue
		queue.append({"item_id": item.id, "slot": item.slot, "id": item.def_id, "kind": item.kind, "tier": item.tier,
			"turns_left": item.turns_left, "total_turns": item.total_turns})
	return {"id": colony.id, "name": GameUI.colony_name(state, colony), "planet": planet.id,
		"kind": planet.type, "seed": planet.art_seed, "slot_count": ColonyRules.slot_count(planet),
		"blocked": planet.blocked_slots.duplicate(), "architecture": state.empires[colony.owner_id].faction_id,
		"stage": ColonyRules.stage(colony), "districts": districts, "buildings": buildings, "queue": queue}
