extends SceneTree
const OUT: String="res://screens/m12_stage_b"
var app: Variant
var probe: Variant
var t: T=T.new()
var scenes: Array[Dictionary]=[]
var captures: Array[String]=[]
func _initialize() -> void: _run.call_deferred()
func _frames(n: int=5) -> void:
	for i: int in n: await process_frame
func _ready_city() -> void:
	var started: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<90000:
		await _frames(2); probe.reveal("PlannerGrid")
		var city: Variant=app.screen.world_controller.host.renderer
		if city!=null and not city.busy and not city.recipe.is_empty(): return
	t.fail("city generation timeout")
func _capture(label: String) -> void:
	root.get_node("Overlay").call("close_all"); await _frames()
	await RenderingServer.frame_post_draw
	t.eq(root.get_texture().get_image().save_png(OUT.path_join(label+".png")),OK)
	captures.append(label+".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT); FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	root.size=Vector2i(1920,1080); root.get_node("Layout").call("set_profile",1)
	root.get_node("Settings").set("persist",false); root.get_node("Settings").call("set_view_mode","command")
	var catcher: Variant=(load("res://tools/m11_stage_c_smoke.gd") as GDScript).ErrorCatcher.new(); OS.add_logger(catcher)
	app=(load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(app)
	probe=load("res://ui/world/stage_e_probe.gd").new(); probe.review_save_dir="user://m12_stage_b_review"; app.add_child(probe)
	await probe.start(app)
	for style: String in ["ark","meridian","vael"]:
		probe.fixture("continental",style,0,15,"huge"); await _ready_city()
		var city: Variant=app.screen.world_controller.host.renderer
		t.eq(city.metrics()["road_version"],2)
		t.ok(not city.routes.is_empty(),"production shared streets are rendered")
		var before: String=root.get_node("Game").get("state").state_hash()
		var fields: Dictionary=root.get_node("Worlds").call("save_fields",root.get_node("Game").get("state"))
		var road_raw: String=load("res://sim/save/presentation_envelope.gd").component_raws(fields["presentation"])["road"]
		var routes_before: Array=city.road_network["routes"].duplicate(true)
		await _capture("01_"+style+"_shared_streets")
		scenes.append({"style":style,"metrics":city.metrics()})
		probe.perform("save"); t.eq(probe.error,"0"); probe.perform("restore"); await _ready_city()
		t.eq(root.get_node("Game").get("state").state_hash(),before,"save retains gameplay")
		var after: Dictionary=root.get_node("Worlds").call("save_fields",root.get_node("Game").get("state"))
		t.eq(load("res://sim/save/presentation_envelope.gd").component_raws(after["presentation"])["road"],road_raw,"road identity survives save/load")
		t.eq(app.screen.world_controller.host.renderer.road_network["routes"],routes_before,"network is rebuildable")
	# Compare the same newer art/geography with the pinned legacy road algorithm.
	var game: Node=root.get_node("Game")
	var worlds: Node=root.get_node("Worlds")
	var saved: Dictionary=worlds.call("save_fields",game.get("state"))
	var old_wrapper: Dictionary=JSON.parse_string(saved["presentation"]); old_wrapper.erase("components")
	var old_state: Variant=game.get("state").clone()
	game.call("resume",old_state,JSON.stringify(old_wrapper),"",false)
	app.go("game"); await _ready_city()
	t.eq(app.screen.world_controller.host.renderer.metrics()["road_version"],1)
	var anchor: Dictionary=worlds.get("appearances").anchor_for(app.screen.colony_id,old_state.colonies[app.screen.colony_id].planet_id)
	await _capture("02_same_city_legacy_roads")
	var update: BaseButton=app.screen.find_child("UpgradeCityRoads",true,false)
	t.ok(update!=null,"legacy campaign exposes explicit road upgrade")
	if update!=null: update.pressed.emit(); await _ready_city()
	t.eq(app.screen.world_controller.host.renderer.metrics()["road_version"],2)
	t.eq(worlds.get("appearances").anchor_for(app.screen.colony_id,old_state.colonies[app.screen.colony_id].planet_id),anchor)
	t.eq(game.get("state").state_hash(),old_state.state_hash())
	await _capture("03_same_city_upgraded_roads")
	app.queue_free(); await _frames(); worlds.call("restart"); await _frames()
	root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
	for error: String in catcher.take(): t.fail(error)
	OS.remove_logger(catcher)
	var evidence: Dictionary={"checks":t.checks,"failures":t.failures,"captures":captures,"scenes":scenes,"qualification":"Production colony renderer, actual newer assemblies and native software OpenGL. Catalog cities are explicit fixtures; no physical Windows or browser runtime claimed."}
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print(JSON.stringify(evidence)); quit(0 if t.failures.is_empty() else 1)
