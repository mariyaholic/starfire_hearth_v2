extends RefCounted

func test_legacy_visible_access_keeps_saved_recipes_and_safe_traffic(t: T) -> void:
	Settings.persist = false
	var state: GameState = ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var legacy: AppearanceProfileStore = AppearanceProfileStore.new(); legacy.bind(state)
	var fields: Dictionary = legacy.save_fields(state)
	Game.resume(state,fields["presentation"],fields["presentation_overlay"])
	var hash: String = Game.state.state_hash()
	var saved: Dictionary = Worlds.save_fields(Game.state)
	var colony: Colony = GameModel.capital(Game.state)
	var description: Dictionary = VisualSnapshotBuilder.build(Game.state,"colony",colony.id,Worlds.session.epoch)
	var before: Dictionary = description.duplicate(true)
	t.eq(description["road_recipe"],{},"a real old save has no upgraded road component")
	var renderer: ColonyRenderer = ColonyRenderer.new()
	renderer.render_scale_divisor = 2
	renderer.bind_services(Worlds.scheduler,Worlds.cache,Worlds.session.epoch,"legacy_traffic_test")
	renderer.configure(description)
	Engine.get_main_loop().root.add_child(renderer)
	for i: int in 10000:
		if not renderer.busy: break
		await Engine.get_main_loop().process_frame
	renderer.set_process(false)
	t.not_ok(renderer.busy)
	t.ok(not renderer.traffic.vehicles.is_empty(),"supported legacy colony has visible frontage deliveries")
	t.eq(renderer.carts.size(),renderer.traffic.vehicles.size())
	var routes: Array = renderer.routes.duplicate(true)
	for vehicle: Dictionary in renderer.traffic.vehicles:
		t.ok(DecorativeTraffic.supports(vehicle["route"],routes),"legacy carts use visible repaired pavement")
	var fleet: Array[Dictionary] = renderer.traffic.vehicles.duplicate(true)
	renderer.configure(description,{"slot":8,"kind":"district","id":"research","valid":true})
	t.eq(renderer.traffic.vehicles,fleet,"placement preview preserves the running fleet")
	t.eq(description,before,"view adapter does not mutate its input snapshot")
	t.eq(Worlds.save_fields(Game.state),saved,"legacy road component and physical recipes remain byte-exact")
	t.eq(Game.state.state_hash(),hash,"the presentation cannot change game math")
	renderer.free(); Worlds.scheduler.cancel_owner("legacy_traffic_test"); Worlds.cache.release_owner("legacy_traffic_test")
	Worlds.restart()

func test_construction_reveal_stops_when_pause_or_reduce_motion_is_enabled(t: T) -> void:
	var saved_persist: bool = Settings.persist
	var saved_reduce_motion: bool = Settings.reduce_motion
	Settings.persist = false
	var renderer: ColonyRenderer = ColonyRenderer.new()
	Engine.get_main_loop().root.add_child(renderer)
	renderer.set_process(false)
	renderer.busy = false
	for setting: String in ["pause", "reduce_motion"]:
		Settings.set_reduce_motion(false)
		renderer.motion_paused = false
		renderer._container.modulate.a = 0.0
		renderer._construction_transition = true
		renderer._transition_installing = true
		renderer._reveal_city()
		var reveal: Tween = renderer._transition_tween
		reveal.pause()
		reveal.custom_step(0.04)
		t.ok(renderer._container.modulate.a > 0.0 and renderer._container.modulate.a < 1.0, "fixture interrupts the visible reveal")
		if setting == "pause": renderer.motion_paused = true
		else: Settings.set_reduce_motion(true)
		renderer._process(0.0)
		t.eq(renderer._container.modulate.a, 1.0, setting + " immediately completes the transition")
		# A stale tween must not make the completed city translucent again.
		if reveal.is_valid(): reveal.custom_step(0.04)
		t.eq(renderer._container.modulate.a, 1.0, setting + " leaves no animated fade behind")
		t.not_ok(reveal.is_valid(), setting + " cancels the reveal tween")
		t.not_ok(renderer._construction_transition)
		reveal.kill()
	renderer.free()
	Settings.set_reduce_motion(saved_reduce_motion)
	Settings.persist = saved_persist
