extends RefCounted
## The app flow (the screen plan in docs/BUILD_PROMPT.md): title → campaign → briefing → game →
## debrief → campaign, driven through the AppRoot, with the explanation and layout audit (§12) on
## every screen as a PC and a phone at 100% and 200% text. Headless, like test_ui_audit.gd.

const S1: String = "s1_first_light"
const PROFILES: Array[Array] = [
	# [window size, phone profile, text scale]
	[Vector2i(1920, 1080), false, 1.0],
	[Vector2i(1920, 1080), false, 2.0],
	[Vector2i(2400, 1080), true, 1.0],
	[Vector2i(2400, 1080), true, 2.0],
]

var _tree: SceneTree
var _root: Window


func test_flow_walks_from_title_to_debrief_and_back(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0])
	t.eq(app.route, AppRoot.TITLE, "the app opens on the title")
	t.ok(app.screen.find_child("Campaign", true, false) != null, "the title offers the campaign")
	t.ok(app.screen.find_child("Showcase", true, false) != null, "debug builds offer the showcase")
	t.ok(app.screen.find_child("Load", true, false) == null, "no Load entry before the load screen exists")
	await _press(app, "Campaign")
	t.eq(app.route, AppRoot.CAMPAIGN)
	t.ok(_has_play(app, S1), "First Light can be played")
	t.not_ok(_has_play(app, "s2_the_crossing"), "The Crossing is locked")
	await _press(app, "Difficulty_hard")
	t.eq(app.progress.difficulty_id, "hard", "the difficulty preset is picked on the campaign screen")
	await _press(app, "Play", app.screen.find_child("Scenario_" + S1, true, false))
	t.eq(app.route, AppRoot.BRIEFING)
	t.eq(app.scenario_id, S1)
	t.ok(app.screen.find_child("Objectives", true, false) != null, "the briefing lists the objectives")
	t.ok(app.screen.find_child("Begin", true, false) != null, "the briefing offers Begin")
	app.go(AppRoot.BEGIN, {"seed": 7})
	await _frames(3)
	t.eq(app.route, AppRoot.GAME, "Begin opens the game")
	var game: Node = _root.get_node("Game")
	var st: GameState = game.get("state")
	t.ok(st != null, "Begin started a game")
	if st == null:
		await _stop(app)
		return
	t.eq(st.scenario_id, S1)
	t.eq(st.difficulty_id, "hard", "the game uses the picked difficulty")
	t.eq(st.game_seed, 7)
	# The game screen is not built yet: end the scenario as the rules would, then debrief.
	st.outcome = GameState.OUTCOME_WON
	st.outcome_turn = 61
	st.outcome_reason = "outcome.all_objectives"
	app.go(AppRoot.DEBRIEF)
	await _frames(3)
	t.eq(app.route, AppRoot.DEBRIEF)
	t.ok(app.progress.is_won(S1), "the win counts as soon as the debrief opens")
	var cont: SfButton = app.screen.find_child("Continue", true, false) as SfButton
	t.ok(cont != null and cont.disabled, "Continue waits for a legacy")
	await (app.screen as DebriefScreen).demo("pick:steady_hands")
	await _frames(2)
	cont = app.screen.find_child("Continue", true, false) as SfButton
	t.ok(cont != null and not cont.disabled, "a picked legacy enables Continue")
	await _press(app, "Continue")
	t.eq(app.route, AppRoot.CAMPAIGN, "Continue returns to the campaign")
	t.eq(app.progress.legacy_of(S1), "steady_hands", "the legacy is recorded")
	t.ok(_has_play(app, S1), "a won scenario can be replayed")
	t.not_ok(_has_play(app, "s2_the_crossing"), "The Crossing is open but not in this build")
	# A loss offers a fresh start from the briefing.
	st.outcome = GameState.OUTCOME_LOST
	st.outcome_reason = "outcome.capital_empty"
	app.go(AppRoot.DEBRIEF)
	await _frames(3)
	t.ok(app.screen.find_child("Retry", true, false) != null, "a loss offers Try again")
	await _press(app, "Retry")
	t.eq(app.route, AppRoot.BRIEFING, "Try again opens the briefing")
	# The showcase is a debug entry with a way back.
	app.go(AppRoot.SHOWCASE)
	await _frames(3)
	t.eq(app.route, AppRoot.SHOWCASE)
	await _press(app, "Back")
	t.eq(app.route, AppRoot.TITLE, "the showcase leads back to the title")
	await _stop(app)


func test_every_flow_screen_passes_the_audit(t: T) -> void:
	for prof: Array in PROFILES:
		var app: AppRoot = await _start(prof)
		var label: String = "%s %s text %d%%" % [prof[0], "phone" if prof[1] else "pc", int(float(prof[2]) * 100)]
		await _audit(t, app, label + " title")
		app.go(AppRoot.CAMPAIGN)
		await _audit(t, app, label + " campaign")
		app.go(AppRoot.BRIEFING, {"scenario": S1})
		await _audit(t, app, label + " briefing")
		app.go(AppRoot.BEGIN, {"seed": 3})
		await _audit(t, app, label + " game stand-in")
		var st: GameState = _root.get_node("Game").get("state")
		st.outcome = GameState.OUTCOME_WON
		st.outcome_turn = 58
		st.outcome_reason = "outcome.all_objectives"
		app.go(AppRoot.DEBRIEF)
		await _audit(t, app, label + " debrief, won")
		await (app.screen as DebriefScreen).demo("pick:archive_scholars")
		await _audit(t, app, label + " debrief, legacy picked")
		app.go(AppRoot.CAMPAIGN)
		await _audit(t, app, label + " campaign after a win")
		st.outcome = GameState.OUTCOME_LOST
		st.outcome_reason = "outcome.capital_autonomy"
		app.go(AppRoot.DEBRIEF)
		await _audit(t, app, label + " debrief, lost")
		await _stop(app)


# --- helpers ------------------------------------------------------------------------------------

func _start(prof: Array) -> AppRoot:
	_tree = Engine.get_main_loop() as SceneTree
	_root = _tree.root
	var settings: Node = _root.get_node("Settings")
	settings.set("persist", false)
	settings.call("set_reduce_motion", true)
	_root.size = prof[0]
	settings.call("set_text_scale", float(prof[2]))
	_root.get_node("Layout").call("set_profile", 2 if prof[1] else 1)
	var app: AppRoot = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	_root.add_child(app)
	await _frames(4)
	return app


func _stop(app: AppRoot) -> void:
	_root.get_node("Overlay").call("close_all")
	app.queue_free()
	var game: Node = _root.get_node("Game")
	game.set("state", null)
	game.set("queue", null)
	await _frames(1)
	_root.get_node("Settings").call("set_text_scale", 1.0)
	_root.get_node("Layout").call("set_profile", 0)


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _has_play(app: AppRoot, scenario_id: String) -> bool:
	var c: Node = app.screen.find_child("Scenario_" + scenario_id, true, false)
	return c != null and c.find_child("Play", true, false) != null


func _press(app: AppRoot, button_name: String, under: Node = null) -> void:
	var host: Node = under if under != null else app.screen
	var b: BaseButton = host.find_child(button_name, true, false) as BaseButton
	if b == null:
		push_error("no button named %s on %s" % [button_name, app.route])
		return
	if b.toggle_mode:
		b.button_pressed = true
	b.pressed.emit()
	await _frames(3)


func _audit(t: T, app: AppRoot, label: String) -> void:
	await _frames(4)
	var view: Rect2 = Rect2(Vector2.ZERO, _root.get_node("Layout").get("logical_size"))
	var rep: IdAudit.AuditReport = IdAudit.run(_root, _root.get_node("Overlay").get("root"), view, _root.get_node("Layout").get("touch_ui"))
	t.ok(rep.checked_labels >= 3, "%s: audited %d labels" % [label, rep.checked_labels])
	for issue: Dictionary in rep.issues.slice(0, 6):
		t.fail("%s: %s %s | %s | %s" % [label, issue["rule"], issue["detail"], issue["text"], issue["path"]])
