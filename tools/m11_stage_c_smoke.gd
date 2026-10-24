extends SceneTree
## Real native scene, commands, lifecycle and responsive audit. Fixtures are named explicitly.
const OUT: String = "res://screens/m11_stage_c"
class ErrorCatcher:
	extends Logger
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _traces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING: errors.append("%s:%d %s" % [file,line,rationale if not rationale.is_empty() else code])
	func _log_message(_message: String, _error: bool) -> void: pass
	func take() -> Array[String]: return errors.duplicate()
var checks: T = T.new()
var app: Variant
var gs: Variant
var settings: Node
var game: Node
var captures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var catcher: Logger = ErrorCatcher.new(); OS.add_logger(catcher)
	settings = root.get_node("Settings"); game = root.get_node("Game")
	settings.set("persist", false); settings.call("set_hints_enabled", false)
	settings.call("set_appearance", "3d"); settings.call("set_visual_quality", "standard")
	root.size = Vector2i(1920,1080); root.get_node("Layout").call("set_profile", 1)
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	app = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	root.add_child(app); await _frames(3)
	app.go("begin", {"scenario":"s1_first_light", "seed":11})
	await _frames(6); root.get_node("Overlay").call("close_all"); await _frames(3)
	gs = app.screen
	gs.show_view("galaxy"); await _frames(6)
	checks.eq(gs.world_controller.host.renderer.get_script().get_global_name(), "GalaxyRenderer")
	checks.ok(gs.find_child("LockedNote",true,false) != null)
	await _capture("01_integrated_galaxy")
	await _click("System_sys_ember")
	checks.eq(gs.view, "system")
	checks.ok(gs.find_child("Open3DSystem",true,false) == null, "study-only system entry is retired")
	checks.ok(gs.find_child("EndTurn",true,false) != null)
	await _capture("02_integrated_system")
	var renderer: Variant = gs.world_controller.host.renderer
	var body_instance: int = renderer.bodies["pl_brume"]["node"].get_instance_id()
	var renderer_instance: int = renderer.get_instance_id()
	var initial_hash: String = game.call("view").state_hash()
	await _click("Focus_pl_brume")
	checks.eq(gs.planet_id,"pl_brume")
	checks.eq(game.call("view").state_hash(), initial_hash, "selection remains presentation-only")
	await _until(func() -> bool: return renderer.bodies["pl_brume"]["width"] >= 1024, 120)
	await _capture("03_focused_brume")
	var probe_id: String = _ship("survey_probe")
	await _click("Survey_"+probe_id)
	checks.ok(game.call("view").ships[probe_id].is_busy())
	checks.eq(gs.world_controller.host.renderer.get_instance_id(),renderer_instance)
	checks.eq(renderer.bodies["pl_brume"]["node"].get_instance_id(),body_instance)
	await _turns(2)
	checks.ok(game.call("view").player().surveyed_planets.has("pl_brume"))
	await _capture("04_survey_completed")
	# Explicit fixture: one extra owned Colony Ship and sufficient influence for the
	# two additional command routes. Commands still validate/pay/complete normally.
	var fixture: GameState = GameState.from_dict(game.call("view").to_dict())
	fixture.player().stock["influence"] = 50000
	var colony: Colony = fixture.colonies_of(fixture.player_id)[0]
	var colony_ship: Ship = Ships.launch(fixture,colony,"colony_ship")
	game.call("resume",fixture); await _frames(5)
	await _click("Focus_"+colony_ship.id)
	checks.ok(gs.find_child("ShipInspector",true,false) != null)
	gs.world_controller.host.renderer.set("_yaw", 0.65)
	await _capture("05_colony_ship")
	await _click("Focus_pl_brume")
	await _click("Colonise_"+colony_ship.id)
	await _turns(1)
	var brume: Colony = game.call("view").colonies[game.call("view").planets["pl_brume"].colony_id]
	checks.ok(renderer_instance != gs.world_controller.host.renderer.get_instance_id(), "resume replaced the session renderer")
	checks.ok(gs.world_controller.host.renderer.bodies.has(brume.id), "completed colony has a selectable owned marker")
	checks.not_ok(gs.world_controller.host.renderer.bodies.has(colony_ship.id), "consumed colony ship is removed")
	await _click("Focus_"+brume.id)
	checks.eq(gs.view,"colony"); checks.ok(gs.find_child("PlannerGrid",true,false) != null)
	gs.show_view("system"); await _frames(5)
	await _click("Focus_pl_tithe")
	await _click("Survey_"+probe_id); await _turns(2)
	var construction_id: String = _ship("construction_ship")
	await _click("Focus_"+construction_id)
	gs.world_controller.host.renderer.set("_yaw", 0.65)
	await _capture("06_construction_ship")
	await _click("Focus_pl_tithe")
	await _click("Outpost_minerals")
	await _turns(4)
	var tithe: Colony = game.call("view").colonies[game.call("view").planets["pl_tithe"].colony_id]
	checks.ok(gs.world_controller.host.renderer.bodies.has(tithe.id), "completed outpost replaces its consumed ship")
	await _click("Focus_"+tithe.id)
	await _capture("07_owned_outpost")
	await _click("Focus_sys_ember")
	await _capture("08_stellar_closeup")
	renderer = gs.world_controller.host.renderer
	var pause: CheckButton = gs.find_child("WorldPause",true,false)
	pause.button_pressed = true
	var frozen: float = renderer.visual_time
	await _frames(5); checks.eq(renderer.visual_time,frozen,"Pause stops the visual clock")
	pause.button_pressed = false
	settings.call("set_reduce_motion",true); await _frames(4)
	frozen = renderer.visual_time; await _frames(4)
	checks.eq(renderer.visual_time,frozen,"Reduced motion stops the visual clock")
	settings.call("set_reduce_motion",false)
	var before_switch: String = game.call("view").state_hash()
	await _click("AppearanceStrategic")
	checks.eq(gs.world_controller.host.renderer,null)
	checks.eq(game.call("view").state_hash(),before_switch)
	await _capture("09_strategic_system")
	await _click("Appearance3D")
	# Appearance fixtures use the normal snapshot/host path, with no additional orders.
	var appearance_fixture: GameState = GameState.from_dict(game.call("view").to_dict())
	for pair: Array in [["pl_brume","arid"],["pl_cinder","ice"],["pl_tithe","toxic"]]:
		appearance_fixture.planets[pair[0]].type = pair[1]
	game.call("resume",appearance_fixture); await _frames(5)
	for pair: Array in [["pl_brume","arid"],["pl_cinder","ice"],["pl_tithe","toxic"]]:
		await _click("Focus_"+pair[0])
		await _until(func() -> bool: return gs.world_controller.host.renderer.bodies[pair[0]]["width"]>=1024,120)
		await _capture("type_"+pair[1])
	for spectral: String in ["M","G","F","A","white_dwarf","binary"]:
		appearance_fixture = GameState.from_dict(game.call("view").to_dict())
		appearance_fixture.systems["sys_ember"].spectral = spectral
		game.call("resume",appearance_fixture); await _frames(5)
		await _click("Focus_sys_ember")
		await _until(func() -> bool: return gs.world_controller.host.renderer.bodies["sys_ember"]["width"]>=1024,120)
		await _capture("star_"+spectral)
	var layouts: Array[Dictionary] = []
	for compact: bool in [false,true]:
		root.get_node("Layout").call("set_profile",2 if compact else 1)
		root.size = Vector2i(2400,1080) if compact else Vector2i(1920,1080)
		for scale: float in [1.0,2.0]:
			settings.call("set_text_scale",scale); await _frames(7)
			var audit: IdAudit.AuditReport = IdAudit.run(root,root.get_node("Overlay").get("root"),Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size")),compact)
			checks.eq(audit.issues.size(),0,"System viewport/inspector PC/phone audit at "+str(scale))
			layouts.append({"phone":compact,"text_scale":scale,"issues":audit.issues})
			await _capture(("phone" if compact else "pc")+"_"+str(int(scale*100)))
	var worlds: Node = root.get_node("Worlds")
	var metrics: Dictionary = {"scheduler":worlds.get("scheduler").call("metrics"),"cache":worlds.get("cache").call("metrics"),"static_bytes":OS.get_static_memory_usage()}
	app.queue_free(); await _frames(5)
	worlds.call("restart"); await _frames(4)
	# Let the existing Audio._exit_tree cleanup reach the mixer before terminating
	# this scripted tour. Abrupt SceneTree.quit can retain an Ogg playback at exit.
	root.get_node("Audio").queue_free()
	await create_timer(0.15).timeout
	for error: String in catcher.call("take"): checks.fail(error)
	OS.remove_logger(catcher)
	var result: Dictionary = {"checks":checks.checks,"failures":checks.failures,"captures":captures,"layouts":layouts,"metrics":metrics,
		"command_fixture":"After canonical Survey coverage: extra Colony Ship and influence=50000 for Colonise/Outpost coverage",
		"appearance_fixture":"Three planet-type substitutions and six spectral substitutions through the ordinary snapshot/host path; no commands issued in those fixtures",
		"renderer":"Godot Compatibility / software OpenGL; physical-device performance remains unverified"}
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("M1.1 STAGE C NATIVE: %d checks, %d failures" % [checks.checks,checks.failures.size()])
	for failure: String in checks.failures: printerr(failure)
	quit(0 if checks.failures.is_empty() else 1)

func _ship(hull: String) -> String:
	for ship: Ship in game.call("view").ships_of(game.call("view").player_id):
		if ship.hull == hull: return ship.id
	return ""

func _turns(count: int) -> void:
	for i: int in count:
		var expected: TurnResult = TurnProcessor.run(GameState.from_dict(game.get("state").to_dict()), game.get("queue").commands())
		game.call("end_turn")
		checks.eq(game.get("state").state_hash(),expected.state_hash,"UI orders match pure turn replay")
		await _frames(5)
		root.get_node("Overlay").call("close_all")

func _click(node_name: String) -> void:
	var named: Node = gs.find_child(node_name,true,false)
	var button: BaseButton = named as BaseButton
	if button == null and named != null:
		for candidate: Node in named.find_children("*","BaseButton",true,false): button=candidate as BaseButton; break
	checks.ok(button != null,"action exists: "+node_name)
	if button == null: return
	checks.not_ok(button.disabled,"action enabled: "+node_name)
	button.pressed.emit(); await _frames(5)

func _capture(label: String) -> void:
	await _frames(3); await RenderingServer.frame_post_draw
	checks.eq(root.get_texture().get_image().save_png(OUT.path_join(label+".png")),OK)
	captures.append(label); print("Captured "+label)

func _frames(count: int) -> void:
	for i: int in count: await process_frame

func _until(condition: Callable, seconds: int) -> void:
	var deadline: int = Time.get_ticks_msec()+seconds*1000
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	checks.ok(condition.call(),"focused surface refinement completed")
