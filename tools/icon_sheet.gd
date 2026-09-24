extends SceneTree
## Icon contact sheet (§8.3): every icon, filled and outlined, at 24 and 16 px, with its name, in
## one tall PNG for review.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s tools/icon_sheet.gd -- --out screens/icon_sheet.png
## Needs a real renderer (not --headless). UI classes are loaded at run time: a -s script that
## names them directly hangs while compiling, because they refer to autoloads that do not exist yet.

const WIDTH: int = 1680


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = "screens/icon_sheet.png"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	if DisplayServer.get_name() == "headless":
		printerr("icon_sheet: needs a display; run under xvfb-run without --headless")
		quit(2)
		return
	var layout: Node = root.get_node("Layout")
	layout.call("set_profile", 1)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(WIDTH, 1200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var page: MarginContainer = MarginContainer.new()
	page.theme = layout.get("theme")
	page.custom_minimum_size.x = WIDTH
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		page.add_theme_constant_override(side, 24)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0B1622")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	vp.add_child(page)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	page.add_child(col)
	var title: Label = Label.new()
	title.theme_type_variation = &"H1Label"
	title.text = str(root.get_node("Strings").call("fmt", "ui.icons.sheet_title"))
	col.add_child(title)
	var sheet_script: GDScript = load("res://ui/screens/showcase/showcase_icons.gd")
	col.add_child(sheet_script.call("build"))
	for i in 3:
		await process_frame
	var h: int = int(page.get_combined_minimum_size().y) + 8
	vp.size = Vector2i(WIDTH, h)
	page.size = Vector2(WIDTH, h)
	bg.size = Vector2(WIDTH, h)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var ignore: FileAccess = FileAccess.open(out.get_base_dir().path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	img.save_png(out)
	print("icon_sheet: %s (%dx%d)" % [out, img.get_width(), img.get_height()])
	quit(0)
