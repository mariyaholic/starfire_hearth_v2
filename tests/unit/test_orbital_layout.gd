extends RefCounted

func test_orbits_are_stable_turn_driven_and_scale_with_distance_and_star_mass(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var recipe: Dictionary=OrbitalLayout.build_recipe(state)
	var replay: Dictionary=OrbitalLayout.build_recipe(state)
	t.eq(recipe,replay,"seeded system/body identities produce the same complete recipe")
	var bodies: Dictionary=recipe["systems"]["sys_ember"]["bodies"]
	t.ok(bodies["pl_cinder"]["period_turns"]<bodies["pl_brume"]["period_turns"])
	t.ok(bodies["pl_brume"]["period_turns"]<bodies["pl_dross"]["period_turns"])
	var initial: Vector3=OrbitalLayout.position(OrbitalLayout.normalize_for_system(recipe,"sys_ember"),"pl_brume",0)
	t.eq(initial,OrbitalLayout.position(OrbitalLayout.normalize_for_system(recipe,"sys_ember"),"pl_brume",bodies["pl_brume"]["period_turns"]),"each body returns to its saved phase at its own period")
	t.ne(initial,OrbitalLayout.position(OrbitalLayout.normalize_for_system(recipe,"sys_ember"),"pl_brume",1),"one campaign turn advances the body")
	state.systems["sys_ember"].spectral="A"
	t.ok(OrbitalLayout.build_recipe(state)["systems"]["sys_ember"]["bodies"]["pl_brume"]["period_turns"]<bodies["pl_brume"]["period_turns"],"greater stellar mass shortens period")

func test_orbit_component_filters_to_disclosed_system_and_body_ids(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state)
	t.ok(store.set_orbital_recipe(OrbitalLayout.build_recipe(state)))
	var filtered: Dictionary=store.orbital_recipe_for("sys_ember",["pl_brume"])
	t.eq(filtered["bodies"].keys(),["pl_brume"])
	t.eq(store.orbital_recipe_for("sys_hidden"),{})
	t.not_ok(JSON.stringify(filtered).contains("pl_cinder"),"undisclosed body records are not copied into renderer input")
	var fields: Dictionary=store.save_fields(state)
	var restored: AppearanceProfileStore=AppearanceProfileStore.new()
	restored.bind(state,str(fields.get("presentation","")),str(fields.get("presentation_overlay","")))
	t.eq(restored.orbital_recipe_for("sys_ember")["bodies"],store.orbital_recipe_for("sys_ember")["bodies"],"saved orbital phase and period survive reload")

func test_old_presentation_gets_an_explicit_orbit_upgrade_without_gameplay_changes(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var hash: String=state.state_hash()
	var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state)
	t.ok(store.can_upgrade_orbits(),"old saves remain on their original orbit until the player opts in")
	var anchor: Dictionary=store.anchor_for("col_0001","pl_aster")
	t.ok(store.upgrade_orbits(state))
	t.ok(not store.can_upgrade_orbits(),"upgrade is one-time and versioned")
	t.eq(store.anchor_for("col_0001","pl_aster"),anchor,"surface geography is preserved")
	t.eq(state.state_hash(),hash,"orbital presentation does not change the campaign")

func test_ring_clearance_is_a_disclosed_only_render_adjustment(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var saved: Dictionary=OrbitalLayout.normalize_for_system(OrbitalLayout.build_recipe(state),"sys_ember")
	var original: Dictionary=saved.duplicate(true)
	var disclosed: Array=[{"id":"pl_cinder","orbit":0,"kind":"barren"},{"id":"pl_aster","orbit":1,"kind":"continental"},{"id":"pl_brume","orbit":2,"kind":"gas_giant"},{"id":"pl_dross","orbit":3,"kind":"gas_giant"}]
	var display: Dictionary=OrbitalLayout.display_recipe(saved,disclosed,1.65)
	var last: float=0.0; var extent: float=1.65*1.25
	for planet: Dictionary in disclosed:
		var radius: float=float(display["bodies"][planet["id"]]["display_milli"])/1000.0
		t.ok(radius-last-extent-OrbitalLayout.body_extent(planet["kind"])>=1.399,"surfaces and ring edges retain a visible gap at conjunction")
		for field: String in ["phase_mdeg","period_turns","distance_milli","epoch_turn"]:
			t.eq(display["bodies"][planet["id"]][field],saved["bodies"][planet["id"]][field],"view spacing does not change saved clock or physical recipe")
		last=radius; extent=OrbitalLayout.body_extent(planet["kind"])
	t.eq(saved,original,"saved authority is immutable")
	var filtered: Dictionary=OrbitalLayout.normalize_for_system(OrbitalLayout.build_recipe(state),"sys_ember",["pl_aster"])
	t.eq(OrbitalLayout.display_recipe(filtered,[disclosed[1]],1.65)["bodies"].keys(),["pl_aster"])
	var path: Array[Vector3]=OrbitalLayout.path_mesh(6.0)
	t.ok(path[0].distance_to(path[-1])<0.0001,"orbit curve closes cleanly")

func test_renderer_draws_noninteractive_orbits_and_moves_followers_with_their_planet(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	state.turn=0
	var old_motion: bool=Settings.reduce_motion; Settings.reduce_motion=false
	for ship: Ship in state.ships.values():
		ship.task_target="pl_aster"
		break
	var store: AppearanceProfileStore=Worlds.appearances
	var previous: Dictionary=store.component_view("orbit")
	store.bind(state); store.set_orbital_recipe(OrbitalLayout.build_recipe(state))
	var snapshot: Dictionary=VisualSnapshotBuilder.build(state,"system","sys_ember",Worlds.session.epoch)
	t.eq(snapshot["turn"],0)
	t.ok(snapshot["orbital_recipe"].has("bodies"))
	Settings.persist=false; Settings.orbit_visible=true; Settings.orbit_opacity=0.72
	var renderer: M1SystemRenderer=M1SystemRenderer.new()
	renderer.bind_services(Worlds.scheduler,Worlds.cache,Worlds.session.epoch,"orbital_fixture")
	renderer.configure(snapshot); Engine.get_main_loop().root.add_child(renderer)
	renderer.size=Vector2(1920,950)
	for frame: int in 3: await Engine.get_main_loop().process_frame
	var outer: float=0.0
	for record: Dictionary in renderer._display_orbital["bodies"].values(): outer=maxf(outer,float(record["display_milli"])/1000.0)
	t.ok(renderer._distance<outer*4.0,"initial overview fits the mounted desktop aspect instead of zero-size layout")
	var extent: Rect2=Rect2(renderer.camera.unproject_position(Vector3(outer,0,0)),Vector2.ZERO)
	for point: Vector3 in OrbitalLayout.path_mesh(outer): extent=extent.expand(renderer.camera.unproject_position(point))
	t.ok(extent.size.y>renderer.size.y*0.5 and Rect2(Vector2.ZERO,renderer.size).encloses(extent),"overview occupies the scene while keeping orbit guides in frame")
	t.eq(renderer._orbit_paths.size(),snapshot["planets"].size())
	for path: MeshInstance3D in renderer._orbit_paths.values():
		t.eq(path.mesh.get_surface_count(),1); t.ok(path.mesh is ImmediateMesh)
		t.eq(path.get_child_count(),0,"orbit lines carry no click areas")
	if not snapshot["ships"].is_empty():
		var ship: Dictionary=snapshot["ships"][0]
		if snapshot["orbital_recipe"]["bodies"].has(ship["target"]):
			var planet_id: String=ship["target"]
			var before: Vector3=(renderer.bodies[planet_id]["node"] as Node3D).position
			var offset: Vector3=renderer.bodies[ship["id"]]["parent_offset"]
			var belt_id: String=""
			for planet: Dictionary in snapshot["planets"]:
				if planet["kind"]=="asteroid_belt": belt_id=planet["id"]
			var belt_before: Vector3=renderer.bodies[belt_id]["node"].position if not belt_id.is_empty() else Vector3.ZERO
			state.turn=1; snapshot=VisualSnapshotBuilder.build(state,"system","sys_ember",Worlds.session.epoch)
			renderer.configure(snapshot)
			t.ok((renderer.bodies[planet_id]["node"] as Node3D).position.distance_to(before)<0.0001,"turn transition starts at the previous displayed location")
			if not belt_id.is_empty(): t.ok(renderer.bodies[belt_id]["node"].position.distance_to(belt_before)<0.0001,"asteroid belts also transition from their old position")
			renderer.motion_paused=true
			renderer._process(0.2)
			t.ok(renderer.bodies[ship["id"]]["node"].position.distance_to(renderer.bodies[planet_id]["node"].position+offset)<0.0001,"ambient pause does not detach orbit-targeted ships")
			if not belt_id.is_empty(): t.ok(absf(renderer.bodies[belt_id]["node"].position.length()-belt_before.length())<0.001,"belt transition follows its orbit")
			renderer.motion_paused=false
			t.ok(absf((renderer.bodies[planet_id]["node"] as Node3D).position.length()-before.length())<0.001,"interpolated motion remains on its orbit")
			renderer._process(2.0)
			t.ok((renderer.bodies[ship["id"]]["node"] as Node3D).position.distance_to((renderer.bodies[planet_id]["node"] as Node3D).position+offset)<0.0001,"ship marker follows its orbiting target")
			if not belt_id.is_empty():
				renderer.focus_body(belt_id,false)
				state.turn=2; snapshot=VisualSnapshotBuilder.build(state,"system","sys_ember",Worlds.session.epoch)
				renderer.configure(snapshot); renderer._process(2.0)
				t.eq(renderer._target,renderer.bodies[belt_id]["node"].position,"focused belt camera follows the resolved orbit")
	renderer.focus_body("pl_aster",false); renderer._apply_orbit_visibility()
	for path: MeshInstance3D in renderer._orbit_paths.values(): t.not_ok(path.visible,"closeups suppress orbit guides")
	renderer.show_overview(); renderer._apply_orbit_visibility()
	for path: MeshInstance3D in renderer._orbit_paths.values(): t.ok(path.visible,"overview restores permitted guides")
	renderer.queue_free(); await Engine.get_main_loop().process_frame
	Settings.reduce_motion=old_motion
	if not previous.is_empty():
		Worlds.appearances.set_orbital_recipe(previous)
	elif Game.has_game():
		Worlds.appearances.bind(Game.state,Game.presentation,Game.presentation_overlay,Game.fresh_appearance)
	else:
		Worlds.appearances.bind(state)
