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


func test_campaign_write_failure_warns_after_debrief_transition(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0])
	var blocked: String = "user://test_campaign_block_%d" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	f.store_string("not a directory")
	f.close()
	app.progress.file_path = blocked.path_join("campaign.json")
	app.go(AppRoot.BEGIN, {"scenario": S1, "seed": 3})
	Game.state.outcome = GameState.OUTCOME_WON
	Game.state.outcome_turn = Game.state.turn
	app.go(AppRoot.DEBRIEF)
	await _frames(3)
	var found: bool = false
	for toast: Node in Overlay._toast_box.get_children():
		if toast is Toast and (toast as Toast).text() == Strings.fmt("ui.campaign.save_failed"): found = true
	t.ok(found, "campaign failure remains visible after the debrief transition")
	t.ok(app.progress.is_won(S1), "the live session retains the win")
	app.progress.file_path = ""
	DirAccess.remove_absolute(blocked)
	await _stop(app)


func test_delete_requires_confirmation_and_preserves_replaced_slot(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0])
	var old_dir: String = SaveService.dir
	var dir: String = "user://test_delete_confirm_%d" % Time.get_ticks_usec()
	SaveService.dir = dir
	var saved: GameState = ScenarioLoader.build(Content.db(), S1, 3)
	t.eq(SaveService.save("manual_1", saved), OK)
	app.go(AppRoot.LOAD)
	var screen: LoadScreen = app.screen as LoadScreen
	screen._delete("manual_1")
	var modal: Modal = Overlay.top() as Modal
	t.ok(modal != null and modal.name == "DeleteSaveConfirmation")
	t.ok(FileAccess.file_exists(dir.path_join("manual_1.json")), "opening confirmation does not delete")
	var cancel: BaseButton = modal.find_child("CancelDelete", true, false) as BaseButton
	cancel.pressed.emit()
	await _frames(3)
	t.ok(FileAccess.file_exists(dir.path_join("manual_1.json")), "cancel keeps save")
	screen._delete("manual_1")
	modal = Overlay.top() as Modal
	var confirm: BaseButton = modal.find_child("ConfirmDelete", true, false) as BaseButton
	saved.turn += 1
	t.eq(SaveService.save("manual_1", saved), OK)
	confirm.pressed.emit()
	await _frames(3)
	t.ok(FileAccess.file_exists(dir.path_join("manual_1.json")), "confirmation cannot delete a replaced slot")
	screen._delete("manual_1")
	modal = Overlay.top() as Modal
	confirm = modal.find_child("ConfirmDelete", true, false) as BaseButton
	app.go(AppRoot.TITLE)
	confirm.pressed.emit()
	t.ok(FileAccess.file_exists(dir.path_join("manual_1.json")), "detached confirmation cannot delete")
	app.go(AppRoot.LOAD)
	screen = app.screen as LoadScreen
	screen._delete("manual_1")
	modal = Overlay.top() as Modal
	confirm = modal.find_child("ConfirmDelete", true, false) as BaseButton
	confirm.pressed.emit()
	await _frames(3)
	t.not_ok(FileAccess.file_exists(dir.path_join("manual_1.json")), "confirmed unchanged slot is deleted")
	DirAccess.remove_absolute(dir)
	SaveService.dir = old_dir
	await _stop(app)


func test_detached_load_screen_cannot_load_or_delete(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0])
	var old_dir: String = SaveService.dir
	var dir: String = "user://test_stale_load_%d" % Time.get_ticks_usec()
	SaveService.dir = dir
	var saved: GameState = ScenarioLoader.build(Content.db(), S1, 3)
	t.eq(SaveService.save("manual_1", saved), OK)
	app.go(AppRoot.LOAD)
	var old_screen: LoadScreen = app.screen as LoadScreen
	app.go(AppRoot.TITLE)
	var current: GameState = Game.state
	old_screen._load("manual_1")
	t.eq(app.route, AppRoot.TITLE, "detached load callback cannot navigate")
	t.ok(Game.state == current, "detached load callback cannot replace session")
	old_screen._delete("manual_1")
	t.ok(FileAccess.file_exists(dir.path_join("manual_1.json")), "detached delete callback cannot remove a save")
	SaveService.delete("manual_1")
	DirAccess.remove_absolute(dir)
	SaveService.dir = old_dir
	await _stop(app)


func test_flow_walks_from_title_to_debrief_and_back(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0])
	t.eq(app.route, AppRoot.TITLE, "the app opens on the title")
	var audio: Node = _root.get_node("Audio")
	t.eq(audio.get("current_music"), "mus_title", "the title cues the main theme")
	t.ok(app.screen.find_child("Campaign", true, false) != null, "the title offers the campaign")
	t.ok(app.screen.find_child("Showcase", true, false) != null, "debug builds offer the showcase")
	t.ok(app.screen.find_child("Load", true, false) != null, "the title offers Load")
	t.ok(app.screen.find_child("Settings", true, false) != null, "the title offers Settings")
	t.ok(app.screen.find_child("Codex", true, false) != null, "the title offers the Codex")
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
	t.eq(audio.get("current_music"), "mus_slowboat_1", "the game cues the scenario's main track")
	var game: Node = _root.get_node("Game")
	var st: GameState = game.get("state")
	t.ok(st != null, "Begin started a game")
	if st == null:
		await _stop(app)
		return
	t.eq(st.scenario_id, S1)
	t.eq(st.difficulty_id, "hard", "the game uses the picked difficulty")
	t.eq(st.game_seed, 7)
	# End the scenario as the rules would, then debrief.
	st.outcome = GameState.OUTCOME_WON
	st.outcome_turn = 61
	st.outcome_reason = "outcome.all_objectives"
	app.go(AppRoot.DEBRIEF)
	await _frames(3)
	t.eq(app.route, AppRoot.DEBRIEF)
	t.ok(app.progress.is_won(S1), "the win counts as soon as the debrief opens")
	t.eq(audio.get("current_music"), "sting_victory", "a win cues the victory sting")
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
		app.go(AppRoot.CODEX)
		await _audit(t, app, label + " codex")
		await (app.screen as CodexScreen).demo("open:building:hydroponics_bay")
		await _audit(t, app, label + " codex entry")
		await (app.screen as CodexScreen).demo("open:mechanic:stability")
		await _audit(t, app, label + " codex mechanics page")
		await (app.screen as CodexScreen).demo("search:stability")
		await _audit(t, app, label + " codex search")
		CodexOverlay.open("mechanic:growth")
		await _audit(t, app, label + " codex over a screen")
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


func test_preview_launch_and_debrief_are_separate_from_campaign(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0])
	app.progress = CampaignProgress.new()
	app.go(AppRoot.CAMPAIGN)
	await _frames(3)
	t.ok(app.screen.find_child("PlayPreview", true, false) != null, "preview is immediately playable")
	await _press(app, "PlayPreview")
	t.eq(app.scenario_id, "m2a_expedition")
	app.go(AppRoot.BEGIN, {"seed": 1})
	await _frames(3)
	Game.state.outcome = GameState.OUTCOME_WON
	app.go(AppRoot.DEBRIEF)
	await _frames(3)
	t.not_ok(app.progress.is_won("m2a_expedition"), "preview win is not campaign progress")
	t.not_ok(app.progress.is_unlocked("s2_the_crossing"), "preview win leaves campaign locked")
	t.ok(app.screen.find_child("PickHint", true, false) == null, "no legacy hint for an empty selection")
	var cont: SfButton = app.screen.find_child("Continue", true, false) as SfButton
	t.ok(cont != null and not cont.disabled, "no legacy is needed to continue")
	await _stop(app)
