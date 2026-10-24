extends SceneTree
## Capture the current production UI for owner review; no game UI changes.
const OUT: String = "res://screens/m12_owner_revalidation"
var app: Variant
var captures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int = 8) -> void:
	for i: int in count: await process_frame

func _city_ready() -> void:
	var deadline: int = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
		var renderer: Variant = app.screen.world_controller.host.renderer
		if renderer != null and not renderer.busy and not renderer.recipe.is_empty():
			await _frames()
			return
	push_error("City generation did not finish within capture deadline")
	quit(1)

func _capture(label: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	var path: String = OUT.path_join(label + ".png")
	var result: int = root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Could not capture " + label)
		quit(1)
		return
	captures.append(label + ".png")
	print("Captured " + label)

func _run() -> void:
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	var settings: Node = root.get_node("Settings")
	settings.set("persist",false)
	settings.call("set_hints_enabled",false)
	settings.call("set_reduce_motion",true)
	settings.call("set_text_scale",1.0)
	settings.call("set_ui_scale",1.0)
	settings.call("set_render_scale",1.0)
	settings.call("set_visual_quality","standard")
	settings.call("set_appearance","3d")
	settings.call("set_view_mode","immersive")
	root.get_node("Layout").call("set_profile",1)
	var workspace_store: Variant = load("res://ui/world/immersive_workspace.gd")
	workspace_store.reset_memory()
	app = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames(3)
	app.call("go","begin",{"scenario":"s1_first_light","seed":11})
	await _frames(10)
	root.get_node("Overlay").call("close_all")
	if "--system-only" in OS.get_cmdline_user_args():
		app.screen.show_view("system")
		await _frames(90)
		await _capture("05_spaced_system")
		app.screen.toggle_immersive_panel("tools")
		await _capture("06_system_appearance_controls")
		app.queue_free()
		await _frames(4)
		root.get_node("Worlds").call("restart")
		quit(0)
		return
	app.screen.show_view("colony")
	await _city_ready()
	await _capture("01_compact_city_default")
	app.screen.select_slot(0)
	await _capture("02_compact_city_inspector")
	app.screen.toggle_immersive_panel("manage")
	await _frames()
	app.screen.find_child("ManageTab_jobs",true,false).pressed.emit()
	await _capture("03_management_jobs")
	app.screen.close_immersive_panel()
	app.screen.show_view("research")
	await _capture("04_research_tabs")
	app.screen.show_view("system")
	await _frames(90)
	await _capture("05_spaced_system")
	app.screen.toggle_immersive_panel("tools")
	await _capture("06_system_appearance_controls")
	app.screen.show_view("colony")
	await _city_ready()
	for finish: String in ["matte","frosted","glossy"]:
		settings.call("set_interface_finish",finish)
		await _capture("07_"+finish+"_actual")
	settings.call("set_interface_finish","frosted")
	settings.call("set_visual_quality","low")
	root.get_node("Layout").call("set_profile",2)
	root.size=Vector2i(1072,2300)
	await _city_ready()
	for scale: float in [1.0,2.0]:
		settings.call("set_text_scale",scale)
		await _frames(12)
		await _capture("08_phone_"+str(int(scale*100)))
	FileAccess.open(OUT.path_join("capture_info.json"),FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info()["string"],"renderer":RenderingServer.get_video_adapter_name(),"resolution":"1920x1080","quality":"standard","ui_scale":1.0,"text_scale":1.0,"scenario":"s1_first_light","seed":11,"captures":captures,"qualification":"Actual updated production UI and renderer. Fresh game, standard desktop and Low phone emulation. No concept image editing."},"\t"))
	print(JSON.stringify({"captures":captures.size(),"directory":OUT}))
	app.queue_free()
	await _frames(4)
	root.get_node("Worlds").call("restart")
	quit(0)
