extends RefCounted

func _state() -> GameState:
	return ScenarioLoader.build(Content.db(),"s1_first_light",11,"normal")


func test_visual_descriptions_preserve_simulation_and_omit_hidden_sites(t: T) -> void:
	var state: GameState = _state()
	var hash: String = state.state_hash()
	var system: Dictionary = M1VisualSnapshot.system_view(state,"sys_ember")
	t.eq(system["planets"].size(),5)
	for planet: Dictionary in system["planets"]:
		if planet["id"] == "pl_aster":
			t.ok(planet.has("blocked")); t.ok(planet["surveyed"])
		else:
			t.not_ok(planet.has("blocked")); t.not_ok(planet.has("traits")); t.not_ok(planet.has("slot_count"))
	var colony: Colony = GameModel.capital(state)
	var description: Dictionary = M1VisualSnapshot.colony_view(state,colony.id)
	t.eq(description["districts"].size(),colony.districts.size())
	t.eq(description["buildings"].size(),colony.buildings.size())
	t.eq(description["architecture"],state.player().faction_id)
	description["districts"].clear(); description["buildings"].clear()
	(system["planets"][1]["traits"] as Array).clear()
	t.eq(state.state_hash(),hash,"renderer copies cannot mutate simulation")


func test_unknown_system_and_foreign_colony_have_no_3d_description(t: T) -> void:
	var state: GameState = _state()
	state.player().known_systems.erase("sys_ember")
	t.eq(M1VisualSnapshot.system_view(state,"sys_ember"),{})
	t.eq(M1VisualSnapshot.colony_view(state,GameModel.capital(state).id),{})
	state = _state()
	var id: String = GameModel.capital(state).id
	state.colonies[id].owner_id = "foreign"
	t.eq(M1VisualSnapshot.colony_view(state,id),{},"survey does not authorize live foreign colony data")


func test_3d_parcels_use_canonical_m1_coordinates_for_all_world_sizes(t: T) -> void:
	for count: int in [12,20,32]:
		var terrain: CityTerrainGenerator = CityTerrainGenerator.new(11)
		var recipe: Dictionary = terrain.layout([],[],count)
		var coordinates: Array[Vector2i] = HexGrid.coords(count)
		t.eq(recipe["slots"].size(),count)
		for i: int in count: t.eq(recipe["slots"][i]["qr"],coordinates[i],"3D selection shares planner slot numbering")


func test_snapshot_keeps_tiers_and_queue_separate_from_completed_sites(t: T) -> void:
	var state: GameState = _state()
	var colony: Colony = GameModel.capital(state)
	colony.districts[0].tier = 3
	var item: BuildItem = BuildItem.new(); item.slot = 8; item.kind = BuildItem.KIND_BUILDING
	item.def_id = "storehouse"; item.total_turns = 2; item.turns_left = 1; colony.queue.append(item)
	var snapshot: Dictionary = M1VisualSnapshot.colony_view(state,colony.id)
	t.eq(snapshot["districts"][0]["tier"],3)
	t.eq(snapshot["queue"][0]["turns_left"],1)
	t.eq(snapshot["buildings"].size(),2,"queued building is not completed geometry")


func test_each_actual_m1_building_has_an_appearance_assembly(t: T) -> void:
	for id: String in Content.db().ids("buildings"):
		t.ok(not M1BuildingKit.build(id,11).is_empty(),"model for "+id)
