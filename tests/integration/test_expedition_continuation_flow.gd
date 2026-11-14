extends RefCounted
## App-level continuation: no turn, atomic session switch and live presentation continuity.

var _tree: SceneTree
var _root: Window
var _old_dir: String
var _old_persist: bool

class DelayedVerifier:
	extends RefCounted
	signal released
	var answer: bool = false
	func verify(_path: String, _written: String) -> bool:
		await released
		return answer

class PendingContinuation:
	extends Node
	var done: bool = false
	var result: Result
	func run(source: GameState, serial: int, generation: int, next: GameState, verifier: Callable) -> void:
		result = await Game._finish_web_continuation(source, serial, generation, next, {}, "fixture", "fixture", verifier)
		done = true

func _frames(count: int = 3) -> void:
	for i: int in count: await _tree.process_frame

func _won() -> GameState:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 37)
	state.turn = 10
	state.outcome = GameState.OUTCOME_WON
	state.outcome_turn = 10
	state.outcome_reason = "outcome.all_objectives"
	for def: Dictionary in Objectives.definitions(state):
		if DictIO.bool_of(def, "required"): state.objectives_done[DictIO.str_of(def, "id")] = 10
	return state

func _start(phone: bool = false) -> AppRoot:
	_tree = Engine.get_main_loop() as SceneTree
	_root = _tree.root
	_old_dir = SaveService.dir
	_old_persist = Settings.persist
	Settings.persist = false
	Settings.set_reduce_motion(true)
	Settings.set_hints_enabled(false)
	Settings.set_view_mode("command")
	Settings.set_appearance("strategic")
	_root.size = Vector2i(2400, 1080) if phone else Vector2i(1920, 1080)
	Settings.set_text_scale(2.0 if phone else 1.0)
	Layout.set_profile(2 if phone else 1)
	var app: AppRoot = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate() as AppRoot
	_root.add_child(app)
	await _frames(4)
	app.progress = CampaignProgress.new()
	return app

func _stop(app: AppRoot, dir: String = "") -> void:
	Settings.persist = false
	Overlay.close_all()
	app.queue_free()
	await _frames(2)
	Game.state = null
	Game.queue = null
	Game.last_result = null
	if not dir.is_empty():
		if FileAccess.file_exists(dir):
			DirAccess.remove_absolute(dir)
		else:
			var d: DirAccess = DirAccess.open(dir)
			if d != null:
				for f: String in d.get_files(): DirAccess.remove_absolute(dir.path_join(f))
			DirAccess.remove_absolute(dir)
	SaveService.dir = _old_dir
	Settings.persist = _old_persist
	Settings.set_text_scale(1.0)
	Layout.set_profile(0)
	await _frames(2)

func _debrief(app: AppRoot, state: GameState) -> DebriefScreen:
	Game.resume(state, "", "", true)
	app.go(AppRoot.DEBRIEF)
	await _frames(4)
	return app.screen as DebriefScreen

func test_continuation_saves_only_auto_and_preserves_live_presentation(t: T) -> void:
	var app: AppRoot = await _start()
	var dir: String = "user://test_continuation_%d" % Time.get_ticks_usec()
	SaveService.dir = dir
	var won: GameState = _won()
	var screen: DebriefScreen = await _debrief(app, won)
	var free: int = ColonyRules.free_slots(won.colonies[won.player().capital_id], won.planets["pl_aster"])[0]
	var sites: Dictionary = Worlds.appearances.data["groundworks"]["sites"]
	var cid: String = won.player().capital_id
	if not sites.has(cid): sites[cid] = []
	if not sites[cid].has(free): sites[cid].append(free)
	t.ok(Worlds.appearances.set_orbital_recipe(OrbitalLayout.build_recipe(won)), "live orbit recipe is present")
	var live: Dictionary = Worlds.save_fields(won)
	var prepared: Array[int] = Worlds.appearances.prepared_for(cid, ColonyRules.slot_count(won.planets["pl_aster"]))
	t.ok(prepared.has(free), "fixture has live groundworks not represented by Game.presentation")
	t.eq(SaveService.save("checkpoint_2", won), OK)
	var checkpoint_before: String = FileAccess.get_file_as_string(dir.path_join("checkpoint_2.json"))
	t.eq(SaveService.save("auto_0", won), OK)
	var old_session: int = Game.session_serial
	var prior_turn: int = won.turn
	var emitted: Array[int] = [0]
	var watch: Callable = func(_result: TurnResult) -> void: emitted[0] += 1
	Game.turn_resolved.connect(watch)
	Settings.persist = true
	var button: BaseButton = screen.find_child("ContinueExpedition", true, false) as BaseButton
	t.ok(button != null and not button.disabled, "win offers a separate continuation action")
	t.ok(screen.find_child("Continue", true, false) != null, "return to campaign remains available")
	if button != null: button.pressed.emit()
	Settings.persist = false
	await _frames(4)
	t.eq(app.route, AppRoot.GAME, "success returns to the live game")
	t.eq(Game.state.turn, prior_turn, "continuation does not advance a turn")
	t.eq(emitted[0], 0, "continuation does not emit turn_resolved")
	t.eq(Game.session_serial, old_session + 1, "one session transition occurred")
	t.ok(ExpeditionContinuation.is_continued(Game.state), "continued intent is recorded")
	t.eq(ExpeditionContinuation.completion_turn(Game.state), prior_turn)
	t.eq(Game.state.outcome, GameState.OUTCOME_NONE)
	t.eq(FileAccess.get_file_as_string(dir.path_join("checkpoint_2.json")), checkpoint_before, "checkpoint remains byte-identical")
	var lr: SaveSerializer.LoadResult = SaveService.load_slot("auto_0")
	t.ok(lr.ok, "continued auto-save loads through the verified envelope")
	if lr.ok:
		t.eq(lr.state.state_hash(), Game.state.state_hash(), "auto-save contains the continued state")
		t.eq(lr.presentation, live["presentation"], "auto-save contains the live presentation")
		t.eq(lr.presentation_overlay, live["presentation_overlay"], "auto-save retains the live overlay")
		t.eq(Game.presentation, live["presentation"], "new session carries live presentation")
		t.eq(Game.presentation_overlay, live["presentation_overlay"], "new session carries live overlay")
		t.ok(Worlds.appearances.prepared_for(cid, ColonyRules.slot_count(Game.state.planets["pl_aster"])).has(free), "prepared ground survives continuation")
		t.ok(not Worlds.appearances.orbital_recipe_for().is_empty(), "orbit recipe survives continuation")
		app.go(AppRoot.CONTINUE, {"state": lr.state, "presentation": lr.presentation, "presentation_overlay": lr.presentation_overlay})
		await _frames(4)
		t.eq(app.route, AppRoot.GAME, "loading the continued save opens the game")
		t.eq(Game.state.turn, prior_turn, "load does not advance a turn")
	Game.turn_resolved.disconnect(watch)
	await _stop(app, dir)

func test_continuation_failure_queue_and_stale_session_are_inert(t: T) -> void:
	var app: AppRoot = await _start()
	var path: String = "user://test_continuation_block_%d" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a directory")
	f.close()
	SaveService.dir = path
	var won: GameState = _won()
	var screen: DebriefScreen = await _debrief(app, won)
	var original_queue: CommandQueue = Game.queue
	var last: TurnResult = TurnResult.new()
	Game.last_result = last
	var serial: int = Game.session_serial
	var before_hash: String = won.state_hash()
	var old_presentation: String = Game.presentation
	var old_overlay: String = Game.presentation_overlay
	Settings.persist = true
	var failed: Result = await Game.continue_expedition(won, serial)
	Settings.persist = false
	t.not_ok(failed.ok, "failed save blocks continuation")
	t.eq(failed.reason_key, "error.continue.save_failed")
	t.ok(Game.state == won and Game.queue == original_queue and Game.last_result == last, "failure retains state, queue and result identities")
	t.eq(Game.session_serial, serial)
	t.eq(won.state_hash(), before_hash)
	t.eq(Game.presentation, old_presentation)
	t.eq(Game.presentation_overlay, old_overlay)
	t.eq(app.route, AppRoot.DEBRIEF)
	t.ok(screen.is_inside_tree(), "debrief remains attached")
	t.eq(FileAccess.get_file_as_string(path), "not a directory", "failure does not overwrite the blocking file")
	var pending: Command = AcknowledgeCommand.create(won.player_id, "fixture_pending")
	t.ok(Game.submit(pending).ok)
	var queued: Result = await Game.continue_expedition(won, serial)
	t.not_ok(queued.ok)
	t.eq(queued.reason_key, "error.continue.pending_orders")
	t.eq(Game.queue.size(), 1, "pending order remains available")
	Game.undo()
	var same_serial_clone: GameState = won.clone()
	Game.state = same_serial_clone
	var stale_identity: Result = await Game.continue_expedition(won, serial)
	t.not_ok(stale_identity.ok, "identity guard rejects a same-serial replacement")
	t.eq(stale_identity.reason_key, "error.continue.stale")
	var button: BaseButton = screen.find_child("ContinueExpedition", true, false) as BaseButton
	if button != null: button.pressed.emit()
	t.ok(Game.state == same_serial_clone and Game.session_serial == serial, "same-serial stale callback cannot replace the new state")
	t.eq(app.route, AppRoot.DEBRIEF, "same-serial stale callback cannot navigate")
	Game.state = won
	Game.resume(won.clone(), "", "", true)
	var fresh_serial: int = Game.session_serial
	if button != null: button.pressed.emit()
	screen._finish()
	t.eq(Game.session_serial, fresh_serial, "old same-seed button cannot continue a newer session")
	t.eq(app.route, AppRoot.DEBRIEF, "stale callback does not navigate")
	await _stop(app, path)


func test_continuation_without_persistence_is_single_activation_and_auditable(t: T) -> void:
	for phone: bool in [false, true]:
		var app: AppRoot = await _start(phone)
		var dir: String = "user://test_continuation_off_%d" % Time.get_ticks_usec()
		SaveService.dir = dir
		var won: GameState = _won()
		var screen: DebriefScreen = await _debrief(app, won)
		var view: Rect2 = Rect2(Vector2.ZERO, Layout.logical_size)
		var audit: IdAudit.AuditReport = IdAudit.run(_root, Overlay.root, view, Layout.touch_ui)
		for issue: Dictionary in audit.issues.slice(0, 6):
			t.fail("debrief %s: %s | %s" % ["phone200" if phone else "desktop", issue["detail"], issue["text"]])
		var serial: int = Game.session_serial
		var button: BaseButton = screen.find_child("ContinueExpedition", true, false) as BaseButton
		t.ok(button != null)
		if button != null: button.pressed.emit()
		var continued: GameState = Game.state
		var after: int = Game.session_serial
		screen._continue_expedition(won, serial)
		screen._finish()
		t.eq(app.route, AppRoot.GAME, "stale return-to-campaign callback cannot leave the continued game")
		t.eq(Game.session_serial, after, "a second activation cannot start another continuation")
		t.ok(Game.state == continued, "double activation does not replace the state")
		t.not_ok(DirAccess.dir_exists_absolute(dir), "persistence off writes no files")
		await _frames(4)
		var gs: GameScreen = app.screen as GameScreen
		t.ok(gs != null)
		if gs != null:
			gs.show_view(GameScreen.OBJECTIVES)
			await _frames(4)
			var completed: Label = gs.find_child("ExpeditionCompleted", true, false) as Label
			t.ok(completed != null and completed.text.contains(Fmt.date(10)), "objectives preserve the original completion date")
			var audit2: IdAudit.AuditReport = IdAudit.run(_root, Overlay.root, view, Layout.touch_ui)
			for issue: Dictionary in audit2.issues.slice(0, 6):
				t.fail("objectives %s: %s | %s" % ["phone200" if phone else "desktop", issue["detail"], issue["text"]])
		await _stop(app, dir)


func test_canonical_and_lost_games_do_not_offer_continuation(t: T) -> void:
	var app: AppRoot = await _start()
	var canonical: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 1)
	canonical.turn = 10
	canonical.outcome = GameState.OUTCOME_WON
	canonical.outcome_turn = 10
	var canonical_screen: DebriefScreen = await _debrief(app, canonical)
	t.ok(canonical_screen.find_child("ContinueExpedition", true, false) == null, "canonical victory has no expedition action")
	var lost: GameState = _won()
	lost.outcome = GameState.OUTCOME_LOST
	lost.outcome_reason = "outcome.capital_empty"
	var lost_screen: DebriefScreen = await _debrief(app, lost)
	t.ok(lost_screen.find_child("ContinueExpedition", true, false) == null, "loss has no expedition action")
	t.ok(lost_screen.find_child("Retry", true, false) != null, "normal loss retry remains")
	await _stop(app)


func test_delayed_browser_confirmation_guards_session_and_rebuilt_actions(t: T) -> void:
	var app: AppRoot = await _start(true)
	var won: GameState = _won()
	var screen: DebriefScreen = await _debrief(app, won)
	var serial: int = Game.session_serial
	var next: GameState = ExpeditionContinuation.begin(won).state
	var verifier: DelayedVerifier = DelayedVerifier.new()
	var pending: PendingContinuation = PendingContinuation.new()
	_root.add_child(pending)
	Game._continuation_generation += 1
	var generation: int = Game._continuation_generation
	Game._continuation_saving = true
	screen._set_continuing(true)
	pending.run(won, serial, generation, next, verifier.verify)
	await _frames(2)
	t.not_ok(pending.done, "browser confirmation holds the operation open")
	var duplicate: Result = await Game.continue_expedition(won, serial)
	t.eq(duplicate.reason_key, "error.continue.saving", "duplicate activation is refused")
	t.not_ok(Game.submit(AcknowledgeCommand.create(won.player_id, "fixture")).ok, "orders are blocked while saving")
	t.eq(Game.queue.size(), 0)
	screen._queue_rebuild()
	await _frames(4)
	var go_button: BaseButton = screen.find_child("ContinueExpedition", true, false) as BaseButton
	var return_button: BaseButton = screen.find_child("Continue", true, false) as BaseButton
	var saving: Label = screen.find_child("SavingExpedition", true, false) as Label
	t.ok(go_button != null and go_button.disabled, "rebuilt expedition action remains disabled")
	t.ok(return_button != null and return_button.disabled, "rebuilt return action remains disabled")
	t.ok(saving != null and saving.visible, "saving status remains visible after rebuild")
	screen._finish()
	t.eq(app.route, AppRoot.DEBRIEF, "return callback is inert while saving")
	var newer: GameState = won.clone()
	Game.resume(newer, "", "", true)
	Game._continuation_generation += 1
	var newer_generation: int = Game._continuation_generation
	Game._continuation_saving = true
	verifier.answer = true
	verifier.released.emit()
	await _frames(2)
	t.ok(pending.done)
	t.eq(pending.result.reason_key, "error.continue.stale", "late confirmation cannot resume the old session")
	t.ok(Game.state == newer and Game._continuation_saving, "late confirmation preserves newer state and busy flag")
	t.eq(Game._continuation_generation, newer_generation)
	t.eq(app.route, AppRoot.DEBRIEF)
	Game._continuation_saving = false
	pending.queue_free()
	await _stop(app)


func test_unconfirmed_browser_save_keeps_winning_session(t: T) -> void:
	var app: AppRoot = await _start()
	var won: GameState = _won()
	await _debrief(app, won)
	var serial: int = Game.session_serial
	var queue: CommandQueue = Game.queue
	var verifier: DelayedVerifier = DelayedVerifier.new()
	var pending: PendingContinuation = PendingContinuation.new()
	_root.add_child(pending)
	Game._continuation_generation += 1
	Game._continuation_saving = true
	pending.run(won, serial, Game._continuation_generation, ExpeditionContinuation.begin(won).state, verifier.verify)
	await _frames(2)
	verifier.released.emit()
	await _frames(2)
	t.eq(pending.result.reason_key, "error.continue.web_unconfirmed")
	t.ok(Game.state == won and Game.queue == queue, "unconfirmed write leaves live state and queue unchanged")
	t.eq(Game.session_serial, serial)
	t.not_ok(Game._continuation_saving, "retry is available after an unconfirmed write")
	t.eq(app.route, AppRoot.DEBRIEF)
	pending.queue_free()
	await _stop(app)
