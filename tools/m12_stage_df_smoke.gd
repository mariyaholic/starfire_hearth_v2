extends SceneTree
## Small native review capture for M1.2 Stage D workspace and Stage F orbit paths.
const OUT: String="res://screens/m12_stage_df"
var failures: Array[String]=[]
var app: Variant

func _initialize() -> void: _run.call_deferred()

func _frames(count: int=6) -> void:
	for i: int in count: await process_frame

func _capture(name: String) -> void:
	await _frames(); await RenderingServer.frame_post_draw
	var result: int=root.get_texture().get_image().save_png(OUT.path_join(name+".png"))
	if result!=OK: failures.append("could not capture "+name)

func _run() -> void:
	root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	var settings: Node=root.get_node("Settings")
	settings.set("persist",false); settings.call("set_hints_enabled",false); settings.call("set_reduce_motion",true)
	settings.call("set_visual_quality","low"); settings.call("set_appearance","3d"); settings.call("set_view_mode","immersive")
	root.get_node("Layout").call("set_profile",1)
	app=(load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(app)
	await _frames(3)
	app.call("go","begin",{"scenario":"s1_first_light","seed":11}); await _frames(10)
	var screen: Variant=app.get("screen")
	root.get_node("Overlay").call("close_all"); screen.show_view("colony"); await _frames(8)
	var workspace: Variant=screen.find_child("ImmersiveWorld",true,false)
	if workspace==null: failures.append("immersive canvas was not built")
	else:
		for kind: String in ["summary"]:
			if not workspace.panels.has(kind): failures.append("default window missing: "+kind)
		for kind: String in ["inspect","manage","queue"]:
			if workspace.panels.has(kind): failures.append("oversized default window returned: "+kind)
		if not screen.find_child("EndTurn",true,false): failures.append("End Turn is unavailable")
	await _capture("01_desktop_immersive_windows")
	screen.show_view("system"); await _frames(12)
	var renderer: Variant=screen.world_controller.host.renderer
	if renderer==null: failures.append("system renderer was not built")
	else:
		if renderer._orbit_paths.size()!=renderer.snapshot.get("planets",[]).size(): failures.append("expected visible orbit paths for disclosed planets")
		var before: Dictionary=renderer.snapshot.duplicate(true)
		if renderer.snapshot.get("orbital_recipe",{}).is_empty(): failures.append("fresh game has no saved orbital recipe")
		if before.get("turn",-1)!=root.get_node("Game").get("state").turn: failures.append("snapshot turn is stale")
		await _capture("02_system_orbit_paths")
		screen.toggle_immersive_panel("tools"); await _frames(6)
		if screen.find_child("OrbitVisibility",true,false)==null: failures.append("orbit visibility control missing from system tools")
		if screen.find_child("OrbitOpacity",true,false)==null: failures.append("orbit opacity control missing from system tools")
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":10,"failures":failures,"engine":Engine.get_version_info()["string"],"renderer":RenderingServer.get_video_adapter_name(),"captures":["01_desktop_immersive_windows.png","02_system_orbit_paths.png"]},"\t"))
	print(JSON.stringify({"failures":failures,"captures":2}))
	app.queue_free(); await _frames(4); root.get_node("Worlds").call("restart"); quit(0 if failures.is_empty() else 1)
