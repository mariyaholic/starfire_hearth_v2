extends Node
## Repeatable 100-cycle lifecycle stress for shared world rendering, settings, orders, saves and
## scene teardown. Native RSS is sampled by tools/m11_stage_g_lifecycle_profile.py.

const OUT: String = "res://build/stage_g/lifecycle"
const SCENARIO: String = "s1_first_light"
const SWITCH_CYCLES: int = 100
const SETTLE_LIMIT_FRAMES: int = 2400

class ErrorCatcher:
	extends Logger
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _traces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s" % [file, line, rationale if not rationale.is_empty() else code])
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func take() -> Array[String]:
		return errors.duplicate()

var root: Window
var app: Variant
var game: Node
var settings: Node
var worlds: Node
var save_service: Node
var checks: T = T.new()
var catcher: Logger
var endpoint_samples: Array[Dictionary] = []
var queue_changes: int = 0
var load_cycles: int = 0
var new_game_cycles: int = 0
var settings_cycles: int = 0
var selection_changes: int = 0
var stale_deliveries: int = 0
var stale_key: String = "m11_stage_g_cancelled_surface"
var cancellation_evidence: Dictionary = {}
var selected_layout_changes: int = 0
var runner_started_ms: int = 0
var stale_handler: Callable = Callable()
var cycle_limit: int = SWITCH_CYCLES
var output_dir: String = OUT


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func _frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame


func _click(name: String, host: Node = null) -> void:
	var parent: Node = host if host != null else app.screen
	var target: Node = parent.find_child(name, true, false)
	var button: BaseButton = target as BaseButton
	if button == null and target != null:
		for child: Node in target.find_children("*", "BaseButton", true, false):
			button = child as BaseButton
			break
	checks.ok(button != null, "production control exists: " + name)
	if button == null or button.disabled:
		checks.fail("production control is enabled: " + name)
		return
	button.pressed.emit()
	await _frames(4)


func _metrics() -> Dictionary:
	var scheduler: Node = worlds.get("scheduler")
	var cache: Variant = worlds.get("cache")
	return {"scheduler": scheduler.call("metrics"), "cache": cache.call("metrics"),
		"static_memory_bytes": OS.get_static_memory_usage(),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}


func _wait_drained(timeout_frames: int = SETTLE_LIMIT_FRAMES) -> Dictionary:
	var scheduler: Node = worlds.get("scheduler")
	for i in timeout_frames:
		var current: Dictionary = scheduler.call("metrics")
		if int(current.get("pending", 0)) == 0 and int(current.get("retiring", 0)) == 0:
			await _frames(4)
			return current
		await get_tree().process_frame
	return scheduler.call("metrics")


func _wait_for_city_ready(label: String) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 90000:
		await get_tree().process_frame
		var screen: Variant = app.screen
		if screen == null or screen.view != GameScreen.COLONY or Settings.appearance != "3d":
			continue
		var host: WorldViewportHost = screen.world_controller.host
		var city: Variant = host.renderer
		if not city is ColonyRenderer or not host.visible or bool(city.get("busy")):
			continue
		var landscape: Variant = city.get("_landscape")
		var city_root: Variant = city.get("_city")
		var metrics: Dictionary = city.call("metrics")
		var finish_meshes: Dictionary = city.get("_finish_meshes")
		var snapshot: Dictionary = city.get("snapshot")
		if not is_instance_valid(landscape) or not is_instance_valid(city_root):
			continue
		if int(metrics.get("completed", 0)) <= 0 or finish_meshes.is_empty() or int(snapshot.get("city_kit_version", 0)) != 3:
			continue
		await RenderingServer.frame_post_draw
		return true
	checks.fail("%s did not reach visible settled current-finish city geometry" % label)
	return false


func _endpoint(label: String, cycles: int) -> void:
	settings.call("set_appearance", "3d")
	settings.call("set_view_mode", "command")
	var screen: Variant = app.screen
	var owned: Array = game.call("view").colonies_of(game.get("state").player_id)
	if screen != null and not owned.is_empty():
		screen.open_colony(owned[0].id)
	await _frames(2)
	var mode_toggle: Node = screen.find_child("ModeToggle", true, false) if screen != null else null
	checks.ok(mode_toggle is BaseButton, label + " provides real 3D layout control")
	if mode_toggle is BaseButton:
		await _click("ModeToggle", screen)
	checks.ok(screen.call("immersive_active"), label + " settles in the Immersive city layout")
	var ready: bool = await _wait_for_city_ready(label)
	checks.ok(ready, label + " reached same-view settled city endpoint")
	var before_hash: String = game.get("state").state_hash()
	await RenderingServer.frame_post_draw
	var scheduler: Node = worlds.get("scheduler")
	var drained: Dictionary = await _wait_drained()
	var sample: Dictionary = _metrics()
	sample["label"] = label
	sample["completed_switch_cycles"] = cycles
	sample["drained"] = int(drained.get("pending", -1)) == 0 and int(drained.get("retiring", -1)) == 0
	sample["wall_time_unix"] = Time.get_unix_time_from_system()
	sample["elapsed_since_runner_start_seconds"] = float(Time.get_ticks_msec() - runner_started_ms) / 1000.0
	sample["state_hash"] = before_hash
	sample["view"] = screen.view if screen != null else ""
	sample["view_mode"] = settings.get("view_mode")
	endpoint_samples.append(sample)
	print("Stage G lifecycle endpoint %s: RSS_external_pending; scheduler %s; cache %s; nodes %s / orphans %s" % [
		label, JSON.stringify(sample["scheduler"]), JSON.stringify(sample["cache"]), sample["node_count"], sample["orphan_node_count"]])


func _assert_endpoint_trends() -> void:
	if endpoint_samples.size() < 3:
		checks.fail("same-view memory trend requires warmup, post-new-game and settled endpoints")
		return
	var first: Dictionary = endpoint_samples.front()
	var last: Dictionary = endpoint_samples.back()
	var first_cache: Dictionary = first.get("cache", {})
	var last_cache: Dictionary = last.get("cache", {})
	checks.ok(int(last.get("node_count", 0)) <= int(first.get("node_count", 0)) + 48, "settled endpoint node count has no material upward trend")
	checks.ok(int(last.get("orphan_node_count", 0)) <= int(first.get("orphan_node_count", 0)) + 16, "settled endpoint orphan node count has no material upward trend")
	checks.ok(int(last.get("object_count", 0)) <= int(first.get("object_count", 0)) + 256, "settled endpoint object count has no material upward trend")
	checks.ok(int(last.get("static_memory_bytes", 0)) <= int(first.get("static_memory_bytes", 0)) + 64 * 1024 * 1024, "Godot static memory has no material endpoint growth")
	checks.ok(int(last_cache.get("entries", 0)) <= int(first_cache.get("entries", 0)) + 2, "same-view settled cache entries remain bounded")
	checks.ok(int(last_cache.get("texture_bytes_estimate", 0)) <= maxi(int(first_cache.get("texture_bytes_estimate", 0)) * 2, int(first_cache.get("texture_bytes_estimate", 0)) + 32 * 1024 * 1024), "same-view settled cache byte trend remains bounded")
	for sample: Dictionary in endpoint_samples:
		checks.ok(bool(sample.get("drained", false)), str(sample.get("label", "endpoint")) + " has no pending or retiring generation jobs")
		checks.eq(int(sample.get("cache", {}).get("pinned", -1)), 1, str(sample.get("label", "endpoint")) + " has exactly the active city's cache pin")


func _load_roundtrip() -> void:
	var before_state: Variant = game.get("state")
	var state_hash: String = before_state.state_hash()
	var before_fields: Dictionary = worlds.call("save_fields", before_state)
	save_service.set("dir", "user://m11_stage_g_lifecycle")
	var slot: String = save_service.call("save_manual", before_state)
	checks.not_ok(slot.is_empty(), "production manual save created during lifecycle stress")
	if slot.is_empty():
		return
	app.call("go", "load", {"back": "game"})
	await _frames(4)
	var card: Node = app.screen.find_child("Save_" + slot, true, false)
	checks.ok(card != null, "new save appears in production Load screen")
	if card != null:
		await _click("Load", card)
	checks.eq(app.route, "game", "load returns to the live campaign")
	checks.eq(game.get("state").state_hash(), state_hash, "load preserves simulation through a world session restart")
	var after_fields: Dictionary = worlds.call("save_fields", game.get("state"))
	checks.eq(after_fields.get("presentation", ""), before_fields.get("presentation", ""), "load preserves the appearance envelope")
	checks.eq(after_fields.get("presentation_overlay", ""), before_fields.get("presentation_overlay", ""), "load preserves staged groundworks")
	save_service.set("dir", "user://saves")
	load_cycles += 1


func _queue_roundtrip() -> void:
	var state: Variant = game.call("view")
	var legal: Array = BotPolicy.legal_commands(state, state.player_id)
	var chosen: Variant = null
	for command: Command in legal:
		if command.type_id() == "pick_research":
			chosen = command
			break
	if chosen == null and not legal.is_empty():
		chosen = legal[0]
	checks.ok(chosen != null, "a legal order is available to exercise rapid queue changes")
	if chosen != null:
		var before_hash: String = state.state_hash()
		var result: Result = game.call("submit", chosen)
		checks.ok(result.ok, "legal order enters production queue")
		await _frames(1)
		checks.ok(game.call("undo") != null, "rapid queue cancellation removes the submitted order")
		checks.eq(game.call("view").state_hash(), before_hash, "cancelled queue leaves simulation hash unchanged")
		queue_changes += 1


func _cycle(index: int) -> void:
	var before_hash: String = game.get("state").state_hash()
	var screen: Variant = app.screen
	var views: Array[String] = ["galaxy", "system", "colony"]
	settings.call("set_appearance", "3d")
	settings.call("set_view_mode", "command")
	screen.show_view(views[index % views.size()])
	await _frames(1)
	if screen.view == "system":
		screen.system_id = "sys_ember"
		var state: Variant = game.call("view")
		if state.systems.has("sys_ember") and not state.systems["sys_ember"].planet_ids.is_empty():
			screen.select_planet(state.systems["sys_ember"].planet_ids[index % state.systems["sys_ember"].planet_ids.size()])
			selection_changes += 1
	elif screen.view == "colony":
		var owned: Array = game.call("view").colonies_of(game.get("state").player_id)
		if not owned.is_empty():
			screen.open_colony(owned[index % owned.size()].id)
			selection_changes += 1
	await _frames(1)
	checks.not_ok(screen.call("immersive_active"), "rapid cycle enters the real Command map layout")
	await _click("ModeToggle", screen)
	checks.ok(screen.call("immersive_active"), "rapid cycle enters the real Immersive map layout")
	selected_layout_changes += 1
	await _frames(1)
	await _click("ImmersiveManage", screen)
	checks.ok(screen.immersive_panel_open, "Immersive management context opens during cycle")
	checks.ok(screen.find_child("ImmersiveContext", true, false) != null, "Immersive management context is mounted")
	var queued_preview: Dictionary = {}
	if screen.view == "colony" and index % 25 == 2:
		queued_preview = await _queue_preview_roundtrip(screen)
	await _click("ImmersiveClose", screen)
	checks.not_ok(screen.immersive_panel_open, "Immersive context closes through its real control")
	await _click("ModeToggle", screen)
	checks.not_ok(screen.call("immersive_active"), "rapid cycle returns to the real Command map layout")
	if not queued_preview.is_empty():
		checks.eq(game.call("view").state_hash(), queued_preview["preview_hash"], "Command layout preserves queued construction preview")
		checks.eq(screen.order_count(), int(queued_preview["orders"]), "Command layout retains queued construction order count")
		await _click("Undo", screen)
		checks.eq(game.call("view").state_hash(), queued_preview["base_hash"], "real Undo control cancels the preserved construction order")
		queue_changes += 1
	if index % 2 == 1:
		screen.show_view("research")
	if game.get("state").state_hash() != before_hash:
		checks.fail("view / settings switch changed simulation state at cycle %d" % (index + 1))
	await _frames(1)


func _queue_preview_roundtrip(screen: Variant) -> Dictionary:
	var base_hash: String = game.get("state").state_hash()
	var view: GameState = game.call("view")
	var chosen: Command = null
	for command: Command in BotPolicy.legal_commands(view, view.player_id):
		if command is PlaceDistrictCommand or command is BuildBuildingCommand:
			chosen = command
			break
	checks.ok(chosen != null, "settled colony has a legal construction command to preserve")
	if chosen == null:
		return {}
	var result: Result = game.call("submit", chosen)
	checks.ok(result.ok, "immersive context test queues a genuine legal construction")
	if not result.ok:
		return {}
	var queued_hash: String = game.call("view").state_hash()
	var orders: int = screen.order_count()
	checks.not_ok(orders <= 0, "colony construction appears in the command preview")
	await _frames(2)
	checks.eq(game.call("view").state_hash(), queued_hash, "open Immersive management preserves queued construction")
	checks.eq(screen.order_count(), orders, "Immersive panel retains the queued order count")
	return {"base_hash": base_hash, "preview_hash": queued_hash, "orders": orders}


func _verify_cancellation() -> void:
	var scheduler: Node = worlds.get("scheduler")
	stale_handler = func(_owner: String, _epoch: int, key: String, _images: Dictionary) -> void:
		if key == stale_key:
			stale_deliveries += 1
	scheduler.surface_ready.connect(stale_handler)
	var epoch: int = int(scheduler.get("epoch"))
	var before: Dictionary = scheduler.call("metrics")
	scheduler.call("request", "stage_g_cancel_owner", epoch, stale_key, "continental", 928341, 2048, 0)
	await _frames(1)
	var accepted: Dictionary = scheduler.call("metrics")
	var tasks: Dictionary = scheduler.get("_tasks")
	var task: Variant = tasks.get(stale_key)
	var worker_id: int = int(task.get("worker")) if task is Object else -1
	checks.ok(int(accepted.get("pending", 0)) == int(before.get("pending", 0)) + 1, "valid continental surface request enters the active generation queue")
	checks.ok(int(accepted.get("active_tasks", 0)) > 0, "cancel probe starts or is scheduled for real surface work")
	checks.ok(not accepted.get("progress", []).is_empty(), "cancel probe exposes real work progress before cancellation")
	checks.ok(worker_id >= 0, "2048-pixel continental worker actually started before cancellation")
	var cancelled_before: int = int(accepted.get("cancelled_jobs", 0))
	scheduler.call("cancel_owner", "stage_g_cancel_owner")
	var cancelled: Dictionary = scheduler.call("metrics")
	checks.eq(int(cancelled.get("cancelled_jobs", 0)), cancelled_before + 1, "cancellation counter advances for the accepted stale probe")
	var drained: Dictionary = await _wait_drained(SETTLE_LIMIT_FRAMES)
	checks.ok(int(scheduler.call("metrics").get("cancelled_jobs", 0)) > int(before.get("cancelled_jobs", 0)), "view churn or explicit stale probe cancelled generation work")
	checks.eq(stale_deliveries, 0, "cancelled generation result did not publish to a stale owner")
	checks.eq(int(drained.get("pending", -1)), 0, "cancelled generation queue drained")
	checks.eq(int(drained.get("retiring", -1)), 0, "retired workers joined before teardown endpoint")
	scheduler.surface_ready.disconnect(stale_handler)
	stale_handler = Callable()
	cancellation_evidence = {"owner": "stage_g_cancel_owner", "key": stale_key, "kind": "continental", "width": 2048,
		"worker_id": worker_id, "before": before, "accepted": accepted, "cancelled": cancelled, "drained": drained,
		"stale_result_publications": stale_deliveries}


func _run() -> void:
	runner_started_ms = Time.get_ticks_msec()
	var cycle_setting: String = OS.get_environment("M11_STAGE_G_CYCLE_LIMIT")
	if not cycle_setting.is_empty():
		cycle_limit = clampi(cycle_setting.to_int(), 1, SWITCH_CYCLES)
	var out_setting: String = OS.get_environment("M11_STAGE_G_OUT_DIR")
	if not out_setting.is_empty():
		output_dir = out_setting
	root.size = Vector2i(1920, 1080)
	root.get_node("Layout").call("set_profile", 1)
	settings = root.get_node("Settings")
	settings.set("persist", false)
	settings.call("set_hints_enabled", false)
	settings.call("set_visual_quality", "low")
	settings.call("set_appearance", "strategic")
	settings.call("set_view_mode", "command")
	game = root.get_node("Game")
	worlds = root.get_node("Worlds")
	save_service = root.get_node("SaveService")
	catcher = ErrorCatcher.new()
	OS.add_logger(catcher)
	DirAccess.make_dir_recursive_absolute(output_dir)
	app = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames(4)
	app.call("go", "begin", {"scenario": SCENARIO, "seed": 3})
	await _frames(4)
	root.get_node("Overlay").call("close_all")
	checks.eq(game.get("state").scenario_id, SCENARIO, "lifecycle begins in a real playable First Light state")
	var initial_hash: String = game.get("state").state_hash()
	var warmup_cycles: int = mini(10, cycle_limit)
	for i in warmup_cycles:
		await _cycle(i)
	await _endpoint("warmup_%d" % warmup_cycles, warmup_cycles)
	for i in 10:
		await _queue_roundtrip()
	for i in range(warmup_cycles, cycle_limit):
		if i == 24:
			await _load_roundtrip()
		elif i == 49:
			app.call("go", "begin", {"scenario": SCENARIO, "seed": 11})
			await _frames(4)
			root.get_node("Overlay").call("close_all")
			new_game_cycles += 1
			checks.eq(game.get("state").game_seed, 11, "new game replaces the previous world session")
		elif i == 74:
			settings.call("set_text_scale", 2.0)
			settings.call("set_high_contrast", true)
			settings.call("set_reduce_motion", true)
			settings_cycles += 1
		elif i == 75:
			settings.call("set_text_scale", 1.0)
			settings.call("set_high_contrast", false)
			settings.call("set_reduce_motion", false)
			settings_cycles += 1
		await _cycle(i)
		if i == 49:
			initial_hash = game.get("state").state_hash()
		if i == 49:
			await _endpoint("after_new_game_50", 50)
	await _verify_cancellation()
	await _endpoint("settled_%d" % cycle_limit, cycle_limit)
	if endpoint_samples.size() >= 3:
		_assert_endpoint_trends()
	var end_hash: String = game.get("state").state_hash()
	checks.eq(end_hash, initial_hash, "presentation lifecycle stress preserves the fresh replacement game's state")
	var before_free: Dictionary = _metrics()
	app.queue_free()
	await _frames(8)
	worlds.call("restart")
	await _frames(8)
	var after_teardown: Dictionary = _metrics()
	checks.eq(int(after_teardown["scheduler"].get("pending", -1)), 0, "scheduler has no pending work after scene teardown")
	checks.eq(int(after_teardown["scheduler"].get("retiring", -1)), 0, "scheduler has no retiring work after scene teardown")
	checks.eq(int(after_teardown["cache"].get("pinned", -1)), 0, "teardown released every cache pin")
	checks.ok(int(after_teardown.get("node_count", 0)) <= int(before_free.get("node_count", 0)) + 48, "scene teardown leaves no material node-count growth")
	checks.ok(int(after_teardown.get("orphan_node_count", 0)) <= int(before_free.get("orphan_node_count", 0)) + 16, "scene teardown leaves no material orphan-node growth")
	for error: String in catcher.call("take"):
		checks.fail(error)
	OS.remove_logger(catcher)
	var report: Dictionary = {
		"qualification": "100 native cycles through real 3D Command and Immersive layouts, management contexts, rapid planet/colony selection, queued construction preview and Undo, LoadScreen, new game, accessibility settings, accepted then cancelled continental surface generation, three comparable settled current-finish city endpoints, and full teardown. Native RSS includes llvmpipe.",
		"checks": checks.checks, "failures": checks.failures, "switch_cycles": cycle_limit,
		"queue_submit_undo_cycles": queue_changes, "load_cycles": load_cycles, "new_game_cycles": new_game_cycles,
		"settings_cycles": settings_cycles, "selection_changes": selection_changes, "layout_changes": selected_layout_changes,
		"stale_result_publications": stale_deliveries, "cancellation_probe": cancellation_evidence, "endpoint_samples": endpoint_samples,
		"before_teardown": before_free, "after_teardown": after_teardown,
		"final_state_hash": end_hash,
	}
	var file: FileAccess = FileAccess.open(output_dir.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("M1.1 STAGE G LIFECYCLE: %d checks, %d failures, %d view-switch cycles" % [checks.checks, checks.failures.size(), cycle_limit])
	for failure: String in checks.failures:
		printerr(failure)
	get_tree().quit(0 if checks.failures.is_empty() else 1)
