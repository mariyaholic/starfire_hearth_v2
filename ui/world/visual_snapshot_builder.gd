class_name VisualSnapshotBuilder
extends RefCounted
## Main-thread disclosure boundary. Geometry and jobs receive these copies only.

static func build(state: GameState, kind: String, entity_id: String, epoch: int) -> Dictionary:
	if state == null or state.player() == null: return {}
	var description: Dictionary = {}
	match kind:
		"system": description = M1VisualSnapshot.system_view(state, entity_id)
		"colony": description = M1VisualSnapshot.colony_view(state, entity_id)
		"galaxy": description = galaxy(state)
	if description.is_empty(): return {}
	var store: AppearanceProfileStore = Worlds.appearances
	if not store.matches(state):
		store = AppearanceProfileStore.new()
		store.bind(state)
	description["appearance_supported"] = not store.fallback
	# Only supported scalar rendering versions cross the disclosure boundary.
	for version: String in ["planet_material","stellar_material","civilian_kit"]:
		description[version+"_version"] = int(store.data["catalog"][version])
	if kind == "system":
		description["turn"] = state.turn
		var disclosed_bodies: Array[String]=[]
		for planet: Dictionary in description["planets"]: disclosed_bodies.append(str(planet["id"]))
		description["orbital_recipe"] = store.orbital_recipe_for(entity_id,disclosed_bodies)
		var star: Dictionary = store.profile_for(entity_id)
		description["appearance"] = star
		if star.is_empty(): description["appearance_supported"] = false
		else:
			description["seed"] = star["seed"]
			description["spectral"] = star.get("spectral",description["spectral"])
		for planet: Dictionary in description["planets"]:
			var p: Dictionary = store.profile_for(planet["id"])
			planet["appearance"] = p
			if p.is_empty(): description["appearance_supported"] = false
			else: planet["seed"] = p["seed"]; planet["kind"] = p["kind"]
		for colony: Dictionary in description["colonies"]:
			colony["anchor"] = store.anchor_for(colony["id"],colony["planet"])
			if colony["anchor"].is_empty(): description["appearance_supported"] = false
	elif kind == "colony":
		description["road_recipe"] = CityRoadRecipes.snapshot(store,entity_id)
		description["parcel_labels"] = _parcel_labels(state,state.colonies[entity_id])
		description["prepared_sites"] = store.prepared_for(entity_id,description["slot_count"])
		description["city_kit_version"] = int(store.data["catalog"]["city_kit"])
		description["architecture"] = store.architecture_for(description["architecture"])
		if description["architecture"].is_empty(): description["appearance_supported"] = false
		description["appearance"] = store.profile_for(description["planet"])
		description["anchor"] = store.anchor_for(entity_id,description["planet"])
		if description["appearance"].is_empty() or description["anchor"].is_empty(): description["appearance_supported"] = false
		else:
			description["seed"] = description["appearance"]["seed"]
			description["kind"] = description["appearance"]["kind"]
	elif kind == "galaxy":
		for marker: Dictionary in description["systems"]:
			if not marker["known"]: continue
			var p: Dictionary = store.profile_for(marker["id"])
			marker["appearance"] = p
			if p.is_empty(): description["appearance_supported"] = false
			else:
				marker["seed"] = p["seed"]
				marker["spectral"] = p.get("spectral",marker["spectral"])
	description["session_epoch"] = epoch
	description["viewer_id"] = state.player_id
	description["view_kind"] = kind
	description["disclosure"] = "owned" if kind == "colony" else "known"
	description["appearance_version"] = SpaceSurfaceBaker.VERSION
	description["revision"] = CanonicalJson.stringify(description).sha256_text()
	return description.duplicate(true)

static func galaxy(state: GameState) -> Dictionary:
	var systems: Array[Dictionary] = []
	for id: String in DictIO.sorted_keys(state.systems):
		var system: StarSystem = state.systems[id]
		var known: bool = state.player().known_systems.has(id)
		var marker: Dictionary = {"id": id, "x": system.x, "y": system.y, "known": known}
		if known:
			marker["name_key"] = system.name_key
			marker["spectral"] = system.spectral
		systems.append(marker)
	var lanes: Array[Dictionary] = []
	for id: String in DictIO.sorted_keys(state.lanes):
		var lane: Lane = state.lanes[id]
		lanes.append({"id": id, "a": lane.a, "b": lane.b, "locked": true})
	return {"id": "galaxy", "systems": systems, "lanes": lanes}

static func _parcel_labels(state: GameState, colony: Colony) -> Array[String]:
	var labels: Array[String]=[]
	var planet: Planet=state.planets[colony.planet_id]
	for slot: int in ColonyRules.slot_count(planet):
		var label: String=Strings.fmt("ui.world.parcel",{"number":slot+1})
		if planet.blocked_slots.has(slot): label+=" · "+Strings.fmt("error.build.blocked_slot")
		elif colony.district_at(slot)!=null: label+=" · "+GameUI.name_of("districts",colony.district_at(slot).district_id)
		elif colony.building_at(slot)!=null: label+=" · "+GameUI.name_of("buildings",colony.building_at(slot).building_id)
		elif colony.queued_at(slot)!=null:
			var item: BuildItem=colony.queued_at(slot)
			label+=" · "+GameUI.name_of("buildings" if item.kind==BuildItem.KIND_BUILDING else "districts",item.def_id)
		labels.append(label)
	return labels
