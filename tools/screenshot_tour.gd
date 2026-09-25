extends SceneTree
## Screenshot tour (§9.9): renders every showcase state and every app screen (title, campaign,
## briefing, the game route, the debrief won, with a legacy picked and lost, the Codex, an entry
## and the Codex over a screen) at 1920x1080 (PC) and 2400x1080 (phone: 440 dpi, touch, simulated
## cut-outs), each at 100% and 200% text, writes the PNGs, runs the IdAudit on every state, and
## writes deuteranopia-simulated copies of the PC 100% set. The debriefs show a real won game: the
## balanced bot plays Scenario 1 to victory once, at the start.
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

## App states: [name, what to do on the AppRoot].
const APP_STATES: Array[Array] = [
	["20_title", "title"],
	["21_campaign", "campaign"],
	["22_briefing", "briefing"],
	["23_game", "game"],
	["24_debrief_won", "debrief_won"],
	["25_debrief_legacy", "debrief_legacy"],
	["26_debrief_lost", "debrief_lost"],
	["27_codex", "codex"],
	["28_codex_entry", "codex_entry"],
	["29_codex_overlay", "codex_overlay"],
]
const APP_SCENE: String = "res://ui/screens/app_root.tscn"

var _out: String = "screens"
var _failed: bool = false
var _shots: int = 0
var _won: GameState = null
var _lost: GameState = null


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
	# Keep Godot's editor from importing the screenshots as textures.
	var ignore: FileAccess = FileAccess.open(_out.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var report: Dictionary = {"profiles": {}, "issue_count": 0, "exemptions": []}
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
			await _capture(prof, prof_dir, state_name, prof_report, report)
		overlay.call("close_all")
		scene.queue_free()
		await _frames(2)
		# The app's screens, from a fresh AppRoot.
		var app: Control = (load(APP_SCENE) as PackedScene).instantiate()
		root.add_child(app)
		await _frames(4)
		for ast: Array in APP_STATES:
			var app_state: String = ast[0]
			if not only_states.is_empty() and not only_states.has(app_state):
				continue
			await _app_state(app, str(ast[1]))
			await _frames(4)
			await _capture(prof, prof_dir, app_state, prof_report, report)
			overlay.call("close_all")
		app.queue_free()
		root.get_node("Game").set("state", null)
		await _frames(2)
		report["profiles"][prof["id"]] = prof_report
	var f: FileAccess = FileAccess.open(_out.path_join("audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ") + "\n")
	f.close()
	print("screenshot_tour: %d screenshots in %s, %d audit issue(s), %d exemption(s), %.1f s" % [
		_shots, _out, report["issue_count"], (report["exemptions"] as Array).size(), (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if int(report["issue_count"]) > 0 else 0)


## Takes the screenshot of the current state, runs the audit on it and records the result.
func _capture(prof: Dictionary, prof_dir: String, state_name: String, prof_report: Dictionary, report: Dictionary) -> void:
	var layout: Node = root.get_node("Layout")
	var overlay: Node = root.get_node("Overlay")
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path: String = prof_dir.path_join(state_name + ".png")
	img.save_png(path)
	_shots += 1
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


## Puts the AppRoot in a named state.
func _app_state(app: Control, what: String) -> void:
	var game: Node = root.get_node("Game")
	match what:
		"title":
			app.call("go", "title")
		"campaign":
			app.call("go", "campaign")
		"briefing":
			app.call("go", "briefing", {"scenario": "s1_first_light"})
		"game":
			app.call("go", "begin", {"scenario": "s1_first_light", "seed": 3})
		"debrief_won":
			game.call("resume", _won_state())
			app.call("go", "debrief")
		"debrief_legacy":
			game.call("resume", _won_state())
			app.call("go", "debrief")
			await _frames(2)
			await app.get("screen").call("demo", "pick:seasoned_farmers")
		"debrief_lost":
			game.call("resume", _lost_state())
			app.call("go", "debrief")
		"codex":
			app.call("go", "codex")
		"codex_entry":
			app.call("go", "codex", {"entry": "building:hydroponics_bay"})
		"codex_overlay":
			app.call("go", "codex", {"entry": "mechanic:stability"})
			await _frames(2)
			(load("res://ui/codex/codex_overlay.gd") as GDScript).call("open", "mechanic:growth")


## A real won game: the balanced bot plays Scenario 1 until it wins (once per tour).
func _won_state() -> GameState:
	if _won == null:
		var run: BotRunner.Run = BotRunner.run(Content.db(), "s1_first_light", "balanced", 3, 120)
		_won = run.final_state
		print("screenshot_tour: the balanced bot finished Scenario 1 on turn %d (%s)" % [_won.outcome_turn, _won.outcome])
	return _won


## The same game, lost to autonomy, for the lost debrief.
func _lost_state() -> GameState:
	if _lost == null:
		_lost = GameState.from_dict(_won_state().to_dict())
		_lost.outcome = GameState.OUTCOME_LOST
		_lost.outcome_reason = "outcome.capital_autonomy"
	return _lost


func _frames(n: int) -> void:
	for i in n:
		await process_frame
