extends SceneTree
## Real M1 flow, controls, construction, surveys and renderer captures.
## xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --path . -s tools/m1_3d_smoke.gd
const OUT: String = "res://screens/m1_incorporation"
const Runner: GDScript = preload("res://tests/run_tests.gd")
var _app: Variant
var _screen: Variant
var _study: Variant
var _checks: T = T.new()

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var catcher: Logger = Runner.ErrorCatcher.new(); OS.add_logger(catcher)
	var settings: Node = root.get_node("Settings")
	settings.set("persist",false); settings.call("set_reduce_motion",true); settings.call("set_hints_enabled",false)
	settings.call("set_text_scale",1.0); root.get_node("Layout").call("set_profile",1)
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	_app = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(_app)
	await _frames(4); await _capture("01_m1_title")
	_app.call("go","begin",{"scenario":"s1_first_light","seed":11}); await _frames(6)
	_screen = _app.get("screen"); root.get_node("Overlay").call("close_all"); await _frames(4)
	await _capture("02_m1_colony_baseline")
	var game: Node = root.get_node("Game")
	var state: GameState = game.call("view"); var hash: String = state.state_hash()
	await _click(_screen,"Open3DCity"); _study = root.get_node("Overlay").call("top")
	await _land_ready()
	var city: Variant = _study.get("renderer")
	_checks.eq(city.get("snapshot")["districts"].size(),6,"actual starting districts")
	_checks.eq(city.get("snapshot")["buildings"].size(),2,"actual Ark hull and spaceport")
	_checks.eq((game.call("view") as GameState).state_hash(),hash,"opening 3D does not issue orders")
	await _capture("03_m1_city_live")
	_study.find_child("3DPlanning",true,false).set("button_pressed",true)
	var slot: int = ColonyRules.free_slots(state.colonies[_screen.get("colony_id")],state.planets["pl_aster"])[0]
	var at: Vector2 = city.get("camera").unproject_position(city.get("slot_areas")[slot].global_position)
	_checks.eq(city.call("pick_slot",at),slot,"3D ray uses M1 slot numbering")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position=city.get_global_position()+at; click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	Input.parse_input_event(click); await _frames(2)
	click=click.duplicate(); click.pressed=false; Input.parse_input_event(click); await _frames(5)
	_checks.eq(_screen.get("slot"),slot,"pointer selection reaches real planner")
	_screen.call("set_pick","district","agriculture"); _study.call("_refresh"); await _frames(4)
	_checks.eq(city.get("ghost").get("id"),"agriculture","real planner choice becomes placement ghost")
	await _capture("04_m1_placement_preview")
	await _click(_study,"Build")
	_checks.eq(city.get("snapshot")["queue"].size(),1,"M1 Build queues real construction")
	_checks.eq(city.get("snapshot")["districts"].size(),6,"queue is not completed district")
	await _capture("05_m1_queued_farm")
	var queued: String = (game.call("view") as GameState).colonies[_screen.get("colony_id")].queue[0].id
	await _click(_study,"Cancel_"+queued)
	_checks.eq(city.get("snapshot")["queue"].size(),0,"M1 Cancel removes construction ghost")
	await _click(_study,"Build")
	var remaining_turns: int = (game.call("view") as GameState).colonies[_screen.get("colony_id")].queue[0].turns_left
	for i: int in remaining_turns: game.call("end_turn")
	await _frames(5); await _land_ready()
	_checks.eq(city.get("snapshot")["districts"].size(),7,"real turns complete farm geometry")
	_checks.eq(city.get("snapshot")["queue"].size(),0,"completed farm leaves queue")
	city.call("show_overview"); await _capture("06_m1_completed_farm")
	var before: String = (game.call("view") as GameState).state_hash()
	settings.call("set_reduce_motion",false); city.set("motion_paused",false)
	var clock: float = city.get("visual_time"); await _frames(6)
	_checks.ok(float(city.get("visual_time"))>clock,"live city motion")
	city.set("motion_paused",true); clock=city.get("visual_time"); await _frames(4)
	_checks.eq(city.get("visual_time"),clock,"city pause")
	city.set("motion_paused",false); settings.call("set_reduce_motion",true); await _frames(4)
	_checks.eq(city.get("visual_time"),clock,"reduced city motion")
	_checks.eq((game.call("view") as GameState).state_hash(),before,"camera and animation do not change M1 state")
	_study.call("close"); await _frames(5)
	_screen.call("open_planet","pl_aster"); await _frames(5); await _capture("07_m1_system_baseline")
	await _click(_screen,"Open3DSystem"); _study=root.get_node("Overlay").call("top"); await _frames(6)
	var space: Variant = _study.get("renderer")
	_checks.eq(space.get("snapshot")["ships"].size(),2,"actual construction ship and probe")
	_checks.eq(space.get("bodies").size(),8,"one star five planets two real ships")
	await _capture("08_m1_system_live")
	space.call("focus_body","pl_aster"); await _surface_ready(space,"pl_aster"); await _capture("09_m1_aster_close")
	_checks.eq(_screen.get("planet_id"),"pl_aster","3D focus reaches actual planet panel")
	space.call("focus_body","pl_brume"); await _surface_ready(space,"pl_brume"); await _capture("10_m1_brume_unsurveyed")
	var probe_id: String = ""
	for ship: Dictionary in space.get("snapshot")["ships"]:
		if ship["hull"] == "survey_probe": probe_id=ship["id"]
	await _click(_study,"Survey_"+probe_id)
	_checks.ok((game.call("view") as GameState).ships[probe_id].is_busy(),"real survey command from 3D inspector")
	await _capture("11_m1_survey_ordered")
	game.call("end_turn"); game.call("end_turn"); await _frames(5)
	_checks.ok((game.call("view") as GameState).player().surveyed_planets.has("pl_brume"),"real survey completes")
	var surveyed: bool = false
	for planet: Dictionary in space.get("snapshot")["planets"]:
		if planet["id"] == "pl_brume": surveyed=planet["surveyed"] and planet.has("blocked")
	_checks.ok(surveyed,"survey completion refreshes 3D description")
	await _surface_ready(space,"pl_brume"); await _capture("12_m1_brume_surveyed")
	_study.call("close"); await _frames(5)
	# A progressed colony comes from real M1 bot play, rather than a development selector.
	var bot: Variant = load("res://tools/bot/bot_runner.gd")
	var run: Variant = bot.run(game.get("db"),"s1_first_light","balanced",11,30)
	game.call("resume",run.final_state)
	_screen.call("select_colony",_screen.get("colony_id"))
	_screen.call("show_view","colony"); await _frames(6)
	await _click(_screen,"Open3DCity"); _study=root.get_node("Overlay").call("top"); await _land_ready()
	city=_study.get("renderer"); await _capture("13_m1_progressed_city")
	_study.find_child("3DDusk",true,false).set("button_pressed",true); await _capture("14_m1_dusk")
	settings.call("set_text_scale",2.0); await _frames(6); await _capture("15_m1_large_text")
	_checks.ok(_study.get("panel").get_global_rect().end.y<=root.size.y,"large text overlay fits screen")
	settings.call("set_text_scale",1.0); root.get_node("Layout").call("set_profile",2)
	root.size=Vector2i(2400,1080); await _frames(8); await _capture("16_m1_phone_city")
	_checks.ok(_study.get("_split").vertical,"compact view stacks controls")
	settings.call("set_text_scale",2.0); await _frames(8); await _capture("17_m1_phone_large_text")
	_checks.ok(_study.get("_body_scroll").get_global_rect().end.y<=_study.size.y,"phone study scroll stays in viewport")
	root.get_node("Overlay").call("close_all"); _app.queue_free(); await _frames(3)
	for error: String in catcher.call("take"): _checks.fail("engine error: "+error)
	OS.remove_logger(catcher)
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":_checks.checks,"failures":_checks.failures,"engine":Engine.get_version_info()["string"],"renderer":RenderingServer.get_video_adapter_name()},"\t"))
	print("M1 INCORPORATION: %d checks, %d failures" % [_checks.checks,_checks.failures.size()])
	for failure: String in _checks.failures: printerr(failure)
	quit(0 if _checks.failures.is_empty() else 1)


func _land_ready() -> void:
	var begin: int = Time.get_ticks_msec()
	while _study.get("renderer").get("busy") and Time.get_ticks_msec()-begin<180000: await process_frame
	_checks.not_ok(_study.get("renderer").get("busy"),"terrain completed")
	await _frames(4)


func _surface_ready(space: Variant,id: String) -> void:
	var begin: int = Time.get_ticks_msec()
	while space.get("bodies")[id]["width"]<1024 and Time.get_ticks_msec()-begin<180000: await process_frame
	_checks.eq(space.get("bodies")[id]["width"],1024,"focused surface completed")
	await _frames(4)


func _click(host: Node,button_name: String) -> void:
	var named: Node = host.find_child(button_name,true,false)
	var button: BaseButton = named as BaseButton
	if button == null and named != null:
		for child: Node in named.find_children("*","BaseButton",true,false):
			button = child as BaseButton; break
	_checks.ok(button != null,"button exists: "+button_name)
	if button == null: return
	_checks.not_ok(button.disabled,"button enabled: "+button_name)
	if button.disabled: return
	button.pressed.emit(); await _frames(5)


func _capture(name: String) -> void:
	await _frames(4); await RenderingServer.frame_post_draw
	var view: Rect2 = Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size"))
	var audit: IdAudit.AuditReport = IdAudit.run(root,root.get_node("Overlay").get("root"),view,root.get_node("Layout").get("touch_ui"))
	_checks.eq(audit.issues.size(),0,"explanation/layout audit: "+name)
	for issue: Dictionary in audit.issues.slice(0,4): printerr(name+": "+JSON.stringify(issue))
	_checks.eq(root.get_texture().get_image().save_png(OUT.path_join(name+".png")),OK,"capture saved")
	print("Captured "+name)


func _frames(count: int) -> void:
	for i: int in count: await process_frame
