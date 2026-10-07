extends RefCounted

func test_owned_markers_and_ship_tasks_are_filtered_before_rendering(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 11)
	var owned: Colony = Colony.new(); owned.id = "owned_outpost"; owned.owner_id = state.player_id
	owned.planet_id = "pl_tithe"; owned.outpost_kind = "minerals"
	state.colonies[owned.id] = owned
	var foreign: Colony = Colony.new(); foreign.id = "SECRET_COLONY"; foreign.owner_id = "foreign"
	foreign.planet_id = "pl_brume"; foreign.outpost_kind = "SECRET_RESOURCE"
	state.colonies[foreign.id] = foreign
	var snapshot: Dictionary = VisualSnapshotBuilder.build(state, "system", "sys_ember", 5)
	t.eq(snapshot["outposts"].size(), 1); t.eq(snapshot["colonies"].size(), 1)
	t.ok(WorldViewController.permits(snapshot, "owned_outpost"))
	t.not_ok(WorldViewController.permits(snapshot, "SECRET_COLONY"))
	foreign.pops = 900; foreign.outpost_kind = "SECRET_CHANGE"
	t.eq(VisualSnapshotBuilder.build(state, "system", "sys_ember", 5), snapshot)
	t.not_ok(JSON.stringify(snapshot).contains("SECRET"))
	var hash: String = state.state_hash()
	snapshot["outposts"].clear()
	t.eq(state.state_hash(), hash)

func test_three_civilian_hulls_have_distinct_blender_part_assemblies(t: T) -> void:
	var kit: SpaceObjectKit = SpaceObjectKit.new()
	var signatures: Array[String] = []
	for hull: String in ["survey_probe", "construction_ship", "colony_ship"]:
		var model: Node3D = kit.ship(hull)
		t.ok(model.get_child_count() >= 7)
		var signature: String = ""
		for child: MeshInstance3D in model.get_children():
			t.ok(child.mesh != null); t.ok(child.material_override != null)
			signature += str(child.position) + str(child.scale)
		t.not_ok(signatures.has(signature))
		signatures.append(signature)
		model.free()
	var facility: Node3D = kit.outpost("minerals")
	t.ok(facility.get_child_count() > 5); facility.free()

func test_every_world_and_stellar_family_has_a_selectable_representation(t: T) -> void:
	Settings.persist = false
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 11)
	state.colonies.clear()
	state.systems["sys_ember"].planet_ids.clear()
	var kinds: Array[String] = SpaceSurfaceBaker.TYPES.duplicate(); kinds.append("asteroid_belt")
	for i: int in kinds.size():
		var planet: Planet = Planet.new()
		planet.id = "fixture_" + kinds[i]; planet.name_key = "planet.aster.name"
		planet.type = kinds[i]; planet.system_id = "sys_ember"; planet.art_seed = i+11; planet.orbit = i+1
		state.planets[planet.id] = planet
		state.systems["sys_ember"].planet_ids.append(planet.id)
	for spectral: String in StarSystem.SPECTRAL_CLASSES:
		state.systems["sys_ember"].spectral = spectral
		var renderer: M1SystemRenderer = M1SystemRenderer.new()
		renderer.bind_services(Worlds.scheduler, Worlds.cache, Worlds.session.epoch, "fixture_"+spectral)
		renderer.configure(VisualSnapshotBuilder.build(state,"system","sys_ember",Worlds.session.epoch))
		Engine.get_main_loop().root.add_child(renderer)
		t.eq(renderer.bodies.size(), 11, "star, eight planet types and two real ships")
		for kind: String in kinds:
			t.ok(renderer.bodies.has("fixture_"+kind))
			t.ok((renderer.bodies["fixture_"+kind]["area"] as Area3D).collision_layer != 0)
		renderer.focus_body("sys_ember", false)
		t.eq(renderer.selected_id, "sys_ember")
		renderer.queue_free()
		await Engine.get_main_loop().process_frame

func test_new_session_cannot_restore_previous_camera_or_apply_old_requests(t: T) -> void:
	Settings.persist = false; Settings.set_hints_enabled(false); Settings.set_appearance("3d")
	Game.new_game("s1_first_light", 11); GameScreen._opened_seed = 11
	var screen: GameScreen = GameScreen.new()
	Engine.get_main_loop().root.add_child(screen)
	screen.show_view(GameScreen.SYSTEM)
	screen.world_controller.focus("pl_brume")
	var previous_epoch: int = Worlds.session.epoch
	var previous: int = screen.world_controller.host.renderer.get_instance_id()
	Game.resume(ScenarioLoader.build(Content.db(), "s1_first_light", 29))
	for i: int in 5: await Engine.get_main_loop().process_frame
	t.ok(Worlds.session.epoch > previous_epoch)
	t.ne(screen.world_controller.host.renderer.get_instance_id(), previous)
	t.eq(screen.world_controller.host.renderer.get("session_epoch"), Worlds.session.epoch)
	t.eq(screen.planet_id, "")
	t.eq(screen.world_controller.host.renderer.get("selected_id"), "")
	screen.queue_free(); Overlay.close_all()
	for i: int in 4: await Engine.get_main_loop().process_frame
	Worlds.restart(); Settings.set_appearance("strategic")

func test_two_finger_drag_zooms_without_changing_selection_or_game_state(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 11)
	var hash: String = state.state_hash()
	var renderer: M1SystemRenderer = M1SystemRenderer.new()
	renderer.size = Vector2(800,500)
	renderer.bind_services(Worlds.scheduler, Worlds.cache, Worlds.session.epoch, "touch_fixture")
	renderer.configure(VisualSnapshotBuilder.build(state,"system","sys_ember",Worlds.session.epoch))
	Engine.get_main_loop().root.add_child(renderer)
	var distance: float = renderer._distance
	for i: int in 2:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = i; touch.position = Vector2(100+i*100,100); touch.pressed = true
		renderer._viewport_input(touch)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 1; drag.position = Vector2(300,100); drag.relative = Vector2(100,0)
	renderer._viewport_input(drag)
	t.eq(renderer._distance, distance/2.0)
	t.eq(renderer.selected_id, "")
	t.eq(state.state_hash(), hash)
	renderer.queue_free()
	await Engine.get_main_loop().process_frame
