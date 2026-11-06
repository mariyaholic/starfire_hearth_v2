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
