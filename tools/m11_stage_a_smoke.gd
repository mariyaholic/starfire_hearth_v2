extends SceneTree
## Native validation of the same integrated/cooperative slice used by the web export.
const OUT: String = "res://screens/m11_stage_a"
const Runner: GDScript = preload("res://tests/run_tests.gd")
var checks: T = T.new()
var profile_only: bool = false

func _initialize() -> void:
	profile_only = "--profile-only" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var catcher: Logger = Runner.ErrorCatcher.new(); OS.add_logger(catcher)
	root.size=Vector2i(1920,1080)
	root.get_node("Layout").call("set_profile",1)
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	var app: Variant = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	root.add_child(app)
	var probe: Variant = load("res://ui/world/stage_a_probe.gd").new(); app.add_child(probe)
	probe.start(app)
	await _until(func() -> bool: return probe.phase=="ready",20)
	var gs: Variant = app.screen
	var slice: Variant = gs.find_child("SpatialSystem",true,false)
	checks.ok(slice!=null,"viewport is in the normal System screen")
	checks.ok(gs.find_child("TopBar",true,false)!=null,"normal game top bar remains")
	checks.ok(gs.find_child("EndTurn",true,false)!=null,"End Turn remains reachable")
	checks.eq(slice.renderer._jobs.size(),0,"cooperative path creates no worker tasks")
	checks.eq(slice.renderer.bodies.size(),8,"actual star, planets and owned ships")
	var pixel: Vector2 = slice.renderer.camera.unproject_position(slice.renderer.bodies["pl_brume"]["node"].global_position)
	var local_pixel: Vector2 = pixel*slice.renderer.size/Vector2(slice.renderer.viewport.size)
	checks.eq(slice.renderer.pick_body(local_pixel),"pl_brume","ray selection agrees with the reduced-resolution viewport")
	await _capture("01_integrated_system")
	await _click(gs,"Focus_pl_brume")
	checks.eq(gs.planet_id,"pl_brume","existing inspector follows focused planet")
	checks.eq(root.get_node("Game").call("view").state_hash(),probe.initial_hash,"selection preserves simulation")
	await _until(func() -> bool: return slice.renderer.bodies["pl_brume"]["width"]>=512,180)
	checks.ok(slice.renderer.cache_texture_bytes_estimate()<16*1024*1024,"focused cache remains inside the proposed low-profile allowance")
	await _capture("02_focused_brume")
	var probe_id: String = ""
	for ship: Dictionary in slice.renderer.snapshot["ships"]:
		if ship["hull"]=="survey_probe": probe_id=ship["id"]
	await _click(gs,"Survey_"+probe_id)
	checks.ok((root.get_node("Game").call("view") as GameState).ships[probe_id].is_busy(),"existing Survey button queues the real order")
	probe.action="resolve_survey"
	await _until(func() -> bool: return probe.phase=="resolved",20)
	checks.eq(probe.actual_hash,probe.expected_hash,"rendered command result matches pure TurnProcessor replay")
	checks.ok((root.get_node("Game").call("view") as GameState).player().surveyed_planets.has("pl_brume"),"two real turns finish the survey")
	await _frames(8)
	await _capture("03_survey_completed")
	probe.call("_publish")
	var data: Dictionary = probe.telemetry.duplicate(true)
	data["checks"] = checks.checks
	var quality_cases: Array[Dictionary] = []
	for compact: bool in [false,true]:
		root.get_node("Layout").call("set_profile",2 if compact else 1)
		root.size=Vector2i(2400,1080) if compact else Vector2i(1920,1080)
		for text_scale: float in [1.0,2.0]:
			root.get_node("Settings").call("set_text_scale",text_scale)
			await _frames(8)
			var audit: IdAudit.AuditReport = IdAudit.run(root,root.get_node("Overlay").get("root"),Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size")),compact)
			checks.eq(audit.issues.size(),0,"integrated PC/phone explanation/layout audit")
			quality_cases.append({"phone":compact,"text_scale":text_scale,"issues":audit.issues})
			await _capture(("phone" if compact else "pc")+"_"+str(int(text_scale*100)))
	app.queue_free(); await _frames(4)
	for error: String in catcher.call("take"): checks.fail(error)
	OS.remove_logger(catcher)
	data["checks"] = checks.checks; data["failures"] = checks.failures; data["layouts"] = quality_cases
	data["profile_only"] = profile_only
	var result_path: String = "res://build/stage_a/native_live.json" if profile_only else OUT.path_join("verification.json")
	DirAccess.make_dir_recursive_absolute(result_path.get_base_dir())
	FileAccess.open(result_path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("M1.1 STAGE A NATIVE: %d checks, %d failures" % [checks.checks,checks.failures.size()])
	for failure: String in checks.failures: printerr(failure)
	quit(0 if checks.failures.is_empty() else 1)

func _until(condition: Callable, seconds: int) -> void:
	var deadline: int = Time.get_ticks_msec()+seconds*1000
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	checks.ok(condition.call(),"stage condition completed")

func _click(host: Node, node_name: String) -> void:
	var named: Node = host.find_child(node_name,true,false)
	var button: BaseButton = named as BaseButton
	if button==null and named!=null:
		for candidate: Node in named.find_children("*","BaseButton",true,false):
			button=candidate as BaseButton; break
	checks.ok(button!=null,"existing action: "+node_name)
	if button==null: return
	checks.not_ok(button.disabled,"action permitted: "+node_name)
	button.pressed.emit(); await _frames(5)

func _capture(name: String) -> void:
	await _frames(3); await RenderingServer.frame_post_draw
	if profile_only: return
	checks.eq(root.get_texture().get_image().save_png(OUT.path_join(name+".png")),OK,"capture saved")
	print("Captured "+name)

func _frames(count: int) -> void:
	for i in count: await process_frame
