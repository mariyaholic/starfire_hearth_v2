extends SceneTree
## Screenshot tour (§9.9): renders every showcase state at 1920x1080 (PC) and 2400x1080 (phone:
## 440 dpi, touch, simulated cut-outs), each at 100% and 200% text, writes the PNGs, runs the
## IdAudit on every state, and writes deuteranopia-simulated copies of the PC 100% set.
##   xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --path . \
##       -s tools/screenshot_tour.gd -- --out screens [--profiles pc_100,phone_200] [--states modal]
## Exits 1 if the audit found anything. Needs a real renderer (not --headless).

const PROFILES: Array[Dictionary] = [
	{"id": "pc_100", "size": Vector2i(1920, 1080), "phone": false, "text": 1.0},
	{"id": "pc_200", "size": Vector2i(1920, 1080), "phone": false, "text": 2.0},
	{"id": "phone_100", "size": Vector2i(2400, 1080), "phone": true, "text": 1.0},
	{"id": "phone_200", "size": Vector2i(2400, 1080), "phone": true, "text": 2.0},
]
## [state name, demo() argument, card to scroll to]
const STATES: Array[Array] = [
	["01_overview", "components", ""],
	["02_breakdown_pinned", "tooltip", ""],
	["03_resources", "components", "CardResources"],
	["04_buttons", "components", "CardButtons"],
	["05_planner_cells", "components", "CardHexes"],
	["06_event_card", "components", "CardEvent"],
	["07_turn_report", "components", "CardReport"],
	["08_type_colour", "components", "CardType"],
	["09_modal", "modal", ""],
	["10_drawer", "drawer", ""],
	["11_bottom_sheet", "sheet", ""],
	["12_toasts", "toasts", ""],
	["13_icons", "icons", ""],
	["14_stars_planets", "worlds", ""],
	["14b_planets", "worlds", "CardPlanets"],
	["15_high_contrast", "components", ""],
	["16_more_drawer", "more", ""],
]

var _out: String = "screens"
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only_profiles: PackedStringArray = PackedStringArray()
	var only_states: PackedStringArray = PackedStringArray()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--profiles" and i + 1 < args.size():
			only_profiles = args[i + 1].split(",")
		elif args[i] == "--states" and i + 1 < args.size():
			only_states = args[i + 1].split(",")
	if DisplayServer.get_name() == "headless":
		printerr("screenshot_tour: needs a display; run under xvfb-run without --headless")
		quit(2)
		return
	var settings: Node = root.get_node("Settings")
	var layout: Node = root.get_node("Layout")
	var overlay: Node = root.get_node("Overlay")
	settings.set("persist", false)
	settings.call("set_reduce_motion", true)
	DirAccess.make_dir_recursive_absolute(_out)
	var report: Dictionary = {"profiles": {}, "issue_count": 0, "exemptions": []}
	var shots: int = 0
	var started: int = Time.get_ticks_msec()
	for prof: Dictionary in PROFILES:
		if not only_profiles.is_empty() and not only_profiles.has(prof["id"]):
			continue
		root.size = prof["size"]
		settings.call("set_high_contrast", false)
		settings.call("set_text_scale", float(prof["text"]))
		layout.call("set_profile", 2 if prof["phone"] else 1)
		await _frames(4)
		var scene: Control = (load("res://ui/screens/showcase/showcase.tscn") as PackedScene).instantiate()
		root.add_child(scene)
		await _frames(4)
		var prof_dir: String = _out.path_join(str(prof["id"]))
		DirAccess.make_dir_recursive_absolute(prof_dir)
		var prof_report: Dictionary = {}
		for st: Array in STATES:
			var state_name: String = st[0]
			if not only_states.is_empty() and not only_states.has(state_name):
				continue
			settings.call("set_high_contrast", state_name == "15_high_contrast")
			await _frames(2)
			await scene.call("demo", st[1])
			await _frames(3)
			if str(st[2]) != "":
				scene.call("scroll_to_card", st[2])
			else:
				var sc: ScrollContainer = scene.find_child("PageScroll", true, false) as ScrollContainer
				if sc != null:
					sc.scroll_vertical = 0
			await _frames(4)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var path: String = prof_dir.path_join(state_name + ".png")
			img.save_png(path)
			shots += 1
			if prof["id"] == "pc_100":
				var dir_cvd: String = _out.path_join("deuteranopia")
				DirAccess.make_dir_recursive_absolute(dir_cvd)
				ColourVision.deuteranopia(img, 2).save_png(dir_cvd.path_join(state_name + ".png"))
			var view: Rect2 = Rect2(Vector2.ZERO, layout.get("logical_size"))
			var res: IdAudit.AuditReport = IdAudit.run(root, overlay.get("root"), view, prof["phone"])
			prof_report[state_name] = {"issues": res.issues, "labels": res.checked_labels, "targets": res.checked_targets}
			report["issue_count"] = int(report["issue_count"]) + res.issues.size()
			for e: Dictionary in res.exemptions:
				e["where"] = "%s/%s" % [prof["id"], state_name]
				report["exemptions"].append(e)
			var mark: String = "ok  " if res.issues.is_empty() else "FAIL"
			print("%s %s/%s: %d labels, %d touch targets, %d issue(s)" % [mark, prof["id"], state_name, res.checked_labels, res.checked_targets, res.issues.size()])
			for iss: Dictionary in res.issues.slice(0, 12):
				print("       %s: %s | %s | %s" % [iss["rule"], iss["detail"], iss["text"], iss["path"]])
			if res.issues.size() > 12:
				print("       ... and %d more" % (res.issues.size() - 12))
		report["profiles"][prof["id"]] = prof_report
		overlay.call("close_all")
		scene.queue_free()
		await _frames(2)
	var f: FileAccess = FileAccess.open(_out.path_join("audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ") + "\n")
	f.close()
	print("screenshot_tour: %d screenshots in %s, %d audit issue(s), %d exemption(s), %.1f s" % [
		shots, _out, report["issue_count"], (report["exemptions"] as Array).size(), (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if int(report["issue_count"]) > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
