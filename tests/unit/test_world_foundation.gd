extends RefCounted

func test_filtered_revisions_do_not_change_when_unknown_system_facts_change(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 11)
	var before: Dictionary = VisualSnapshotBuilder.build(state, "galaxy", "", 7)
	for system: StarSystem in state.systems.values():
		if state.player().known_systems.has(system.id): continue
		system.spectral = "binary"; system.name_key = "SECRET"; system.owner_id = "foreign"
		system.planet_ids.clear(); system.specials.append("SECRET")
	t.eq(VisualSnapshotBuilder.build(state, "galaxy", "", 7), before)
	for marker: Dictionary in before["systems"]:
		if not marker["known"]:
			t.not_ok(marker.has("spectral")); t.not_ok(marker.has("name_key"))
	var system: Dictionary = VisualSnapshotBuilder.build(state, "system", "sys_ember", 7)
	t.ok(WorldViewController.permits(system, "pl_brume"))
	t.not_ok(WorldViewController.permits(system, "foreign_ship"))
	system["planets"].clear()
	t.eq(state.systems["sys_ember"].planet_ids.size(), 5, "renderer copies stay detached")

func test_cache_lru_active_pins_and_epoch_invalidation(t: T) -> void:
	var cache: VisualResourceCache = VisualResourceCache.new()
	cache.budget_bytes = 100
	cache.pin("a", "first"); cache.pin("a", "second")
	cache.put("a", {"marker": "a"}, 70, 1)
	cache.put("b", {"marker": "b"}, 70, 1)
	t.ok(cache.entries.has("a")); t.not_ok(cache.entries.has("b"))
	cache.release_owner("first")
	cache.pin("c", "third")
	cache.put("c", {"marker": "c"}, 70, 1)
	t.eq(cache.metrics()["overrun_bytes"], 40, "active quality costs are recorded")
	cache.release_owner("second")
	t.not_ok(cache.entries.has("a")); t.eq(cache.bytes, 70)
	cache.reset(2)
	t.not_ok(cache.put("late", {"marker": "stale"}, 70, 1))
	t.ok(cache.get_maps("c", 1).is_empty()); t.eq(cache.bytes, 0)

func test_camera_store_is_bounded_and_new_session_discards_old_focus(t: T) -> void:
	var session: VisualSession = VisualSession.new()
	for i: int in 40: session.remember(str(i), {"distance": i})
	t.eq(session.cameras.size(), 32)
	t.ok(session.recall("0").is_empty())
	var copy: Dictionary = session.recall("39"); copy["distance"] = 0
	t.eq(session.recall("39")["distance"], 39)
	session.restart()
	t.eq(session.epoch, 2); t.ok(session.cameras.is_empty())

func test_generation_prioritizes_focus_deduplicates_and_rejects_old_epoch(t: T) -> void:
	var scheduler: GenerationScheduler = GenerationScheduler.new()
	scheduler.cooperative = true; scheduler.slice_us = 5000
	Engine.get_main_loop().root.add_child(scheduler)
	var results: Array[Dictionary] = []
	scheduler.surface_ready.connect(func(owner: String, epoch: int, key: String, images: Dictionary) -> void:
		results.append({"owner": owner, "epoch": epoch, "key": key, "images": images}))
	scheduler.request("old", 0, "stale", "ice", 29, 32)
	scheduler.request("overview", 1, "overview", "barren", 11, 32, 10)
	scheduler.request("focus", 1, "focus", "ice", 29, 32, 0)
	scheduler.request("second", 1, "focus", "ice", 29, 32, 0)
	scheduler.cancel_owner("second")
	for i: int in 120:
		if results.size() == 2: break
		await Engine.get_main_loop().process_frame
	t.eq(results.size(), 2)
	if results.size() == 2:
		t.eq(results[0]["key"], "focus")
		var expected: Dictionary = SpaceSurfaceBaker.bake("ice", 29, 32)
		t.eq((results[0]["images"]["albedo"] as Image).get_data(), (expected["albedo"] as Image).get_data())
	scheduler.request("cancelled", 1, "cancelled", "ice", 5, 512)
	await Engine.get_main_loop().process_frame
	scheduler.restart(2)
	for i: int in 3: await Engine.get_main_loop().process_frame
	t.eq(results.size(), 2, "retired work does not publish")
	scheduler.queue_free()
	await Engine.get_main_loop().process_frame

func test_native_generation_retirement_does_not_wait_for_large_surface(t: T) -> void:
	var scheduler: GenerationScheduler = GenerationScheduler.new()
	scheduler.cooperative = false
	Engine.get_main_loop().root.add_child(scheduler)
	var results: Array[String] = []
	scheduler.surface_ready.connect(func(_owner: String, _epoch: int, key: String, _images: Dictionary) -> void: results.append(key))
	scheduler.request("leaving", 1, "large", "continental", 11, 2048)
	for i: int in 2: await Engine.get_main_loop().process_frame
	var started: int = Time.get_ticks_usec()
	scheduler.cancel_owner("leaving")
	t.ok(Time.get_ticks_usec() - started < 20000, "navigation retires without joining unfinished work")
	scheduler.request("current", 1, "small", "ice", 29, 32, 0)
	for i: int in 120:
		if results.has("small"): break
		await Engine.get_main_loop().process_frame
	t.eq(results, ["small"])
	scheduler.queue_free()
	await Engine.get_main_loop().process_frame

func test_cooperative_scheduler_suspend_drains_and_rejects_new_requests(t: T) -> void:
	var scheduler: GenerationScheduler = GenerationScheduler.new()
	scheduler.cooperative = true
	Engine.get_main_loop().root.add_child(scheduler)
	var results: Array[String] = []
	scheduler.surface_ready.connect(func(_owner: String, _epoch: int, key: String, _images: Dictionary) -> void: results.append(key))
	scheduler.request("live", 1, "before_loss", "ice", 29, 512)
	t.eq(scheduler.metrics()["pending"], 1, "cooperative work is accepted before suspension")
	scheduler.suspend("webgl_context_lost")
	var stopped: Dictionary = scheduler.metrics()
	t.ok(stopped["suspended"]); t.eq(stopped["suspend_reason"], "webgl_context_lost")
	t.eq(stopped["pending"], 0); t.eq(stopped["retiring"], 0)
	scheduler.request("live", 1, "after_loss", "ice", 29, 32)
	t.eq(scheduler.metrics()["pending"], 0, "suspended cooperative scheduler rejects new work")
	t.not_ok(scheduler.is_processing(), "idle cooperative scheduler stops processing after suspension")
	t.eq(scheduler.get("epoch"), 1, "suspension does not change the live session epoch")
	await _scheduler_frames(3)
	t.empty(results, "suspended generation publishes no result")
	t.ok(scheduler.metrics()["suspended"], "restore is left to page reload")
	scheduler.queue_free()
	await Engine.get_main_loop().process_frame

func test_worker_scheduler_suspend_cancels_joins_and_rejects_new_requests(t: T) -> void:
	var scheduler: GenerationScheduler = GenerationScheduler.new()
	scheduler.cooperative = false
	Engine.get_main_loop().root.add_child(scheduler)
	var results: Array[String] = []
	scheduler.surface_ready.connect(func(_owner: String, _epoch: int, key: String, _images: Dictionary) -> void: results.append(key))
	scheduler.request("live", 1, "worker_before_loss", "continental", 928341, 2048)
	var worker_id: int = -1
	for i: int in 120:
		var tasks: Dictionary = scheduler.get("_tasks")
		var task: Variant = tasks.get("worker_before_loss")
		worker_id = int(task.get("worker")) if task is Object else -1
		if worker_id >= 0: break
		await Engine.get_main_loop().process_frame
	t.ok(worker_id >= 0, "large worker request is accepted and starts before suspension")
	scheduler.suspend("webgl_context_lost")
	var stopped: Dictionary = scheduler.metrics()
	t.ok(stopped["suspended"]); t.eq(stopped["pending"], 0)
	scheduler.request("live", 1, "worker_after_loss", "ice", 29, 32)
	t.eq(scheduler.metrics()["pending"], 0, "suspended worker scheduler rejects new work")
	t.ok(int(stopped["retiring"]) <= 1, "suspend moves only the accepted worker into retirement")
	var drained: Dictionary = stopped
	for i: int in 600:
		drained = scheduler.metrics()
		if int(drained["retiring"]) == 0: break
		await Engine.get_main_loop().process_frame
	t.eq(drained["retiring"], 0, "cancelled worker is joined before suspension settles")
	t.not_ok(scheduler.is_processing(), "worker scheduler stops polling after retirement drains")
	t.eq(scheduler.get("epoch"), 1, "worker suspension preserves the world session epoch")
	t.empty(results, "cancelled worker cannot publish after context loss")
	t.ok(scheduler.metrics()["suspended"], "worker scheduler remains paused until reload")
	scheduler.queue_free()
	await Engine.get_main_loop().process_frame

func _scheduler_frames(count: int) -> void:
	for i: int in count: await Engine.get_main_loop().process_frame

func test_renderer_and_camera_survive_order_refresh_and_responsive_relayout(t: T) -> void:
	Settings.persist = false
	Settings.set_hints_enabled(false); Settings.set_appearance("3d")
	Game.new_game("s1_first_light", 11)
	GameScreen._opened_seed = 11
	var screen: GameScreen = GameScreen.new()
	Engine.get_main_loop().root.add_child(screen)
	screen.show_view(GameScreen.SYSTEM)
	for i: int in 5: await Engine.get_main_loop().process_frame
	var host: WorldViewportHost = screen.world_controller.host
	var renderer: M1SystemRenderer = host.renderer
	t.ok(renderer != null)
	if renderer != null:
		var instance: int = renderer.get_instance_id()
		var planet_node: int = renderer.bodies["pl_brume"]["node"].get_instance_id()
		screen.world_controller.focus("pl_brume")
		renderer._yaw = 0.73
		var hash: String = Game.view().state_hash()
		screen._refresh()
		screen._relayout()
		for i: int in 5: await Engine.get_main_loop().process_frame
		t.eq(host.renderer.get_instance_id(), instance)
		t.eq(renderer.bodies["pl_brume"]["node"].get_instance_id(), planet_node)
		t.eq(renderer._yaw, 0.73)
		t.eq(Game.view().state_hash(), hash)
		screen.show_view(GameScreen.RESEARCH)
		t.eq(host.renderer, null, "inactive geometry releases its resources")
		screen.show_view(GameScreen.SYSTEM)
		for i: int in 3: await Engine.get_main_loop().process_frame
		t.eq(host.renderer.get("selected_id"), "pl_brume")
		t.eq(host.renderer.get("_yaw"), 0.73, "Back restores the session camera")
		host.fail_presentation()
		t.eq(Settings.appearance, "strategic")
		t.eq(Game.view().state_hash(), hash, "fallback preserves the game")
	screen.queue_free()
	Overlay.close_all()
	for i: int in 4: await Engine.get_main_loop().process_frame
	Worlds.restart()
	Settings.set_appearance("strategic")
