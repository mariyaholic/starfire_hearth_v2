extends RefCounted
## Regressions for navigation and repeated input at turn/session boundaries.

const S1: String = "s1_first_light"
var tree: SceneTree

func _start() -> AppRoot:
	tree = Engine.get_main_loop() as SceneTree
	Settings.persist = false
	Settings.set_reduce_motion(true)
	Settings.set_hints_enabled(false)
	GameScreen._opened_session = -1
	var app: AppRoot = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.go(AppRoot.BEGIN, {"scenario": S1, "seed": 71})
	await tree.process_frame
	await tree.process_frame
	return app

func _stop(app: AppRoot) -> void:
	Overlay.close_all()
	app.queue_free()
	await tree.process_frame
	Game.state = null
	Game.queue = null
	Game.last_result = null
	Settings.set_hints_enabled(true)

func test_double_confirm_resolves_once(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	var screen: GameScreen = app.screen as GameScreen
	screen.end_turn()
	var check: Control = Overlay.top()
	t.eq(check.name, "EndTurnChecklist")
	var button: BaseButton = check.find_child("EndAnyway", true, false) as BaseButton
	var before: int = Game.state.turn
	button.pressed.emit()
	button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	t.eq(Game.state.turn, before + 1, "repeated confirmation resolves a single turn")
	await _stop(app)

func test_confirm_then_leave_does_not_advance(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	(app.screen as GameScreen).end_turn()
	var button: BaseButton = Overlay.top().find_child("EndAnyway", true, false) as BaseButton
	var before: int = Game.state.turn
	button.pressed.emit()
	app.go(AppRoot.TITLE)
	await tree.process_frame
	await tree.process_frame
	t.eq(Game.state.turn, before, "leaving before deferred confirmation cancels it")
	t.eq(app.route, AppRoot.TITLE)
	t.eq(Overlay.stack_size(), 0, "old screen cannot open a report on title")
	await _stop(app)

func test_new_session_same_seed_has_opening_report(t: T) -> void:
	var app: AppRoot = await _start()
	t.eq(Overlay.top().name, "TurnReport")
	app.go(AppRoot.TITLE)
	app.go(AppRoot.BEGIN, {"scenario": S1, "seed": 71})
	await tree.process_frame
	await tree.process_frame
	var top: Control = Overlay.top()
	t.ok(top != null and top.name == "TurnReport", "a new session opens its report even with the same seed")
	await _stop(app)

func test_immediate_navigation_cancels_deferred_start(t: T) -> void:
	var app: AppRoot = await _start()
	app.go(AppRoot.BEGIN, {"scenario": S1, "seed": 72})
	app.go(AppRoot.TITLE)
	await tree.process_frame
	await tree.process_frame
	t.eq(Overlay.stack_size(), 0, "removed game screen cannot open its starting report")
	await _stop(app)

func test_confirm_then_new_session_does_not_advance_new_game(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	(app.screen as GameScreen).end_turn()
	var button: BaseButton = Overlay.top().find_child("EndAnyway", true, false) as BaseButton
	button.pressed.emit()
	app.go(AppRoot.BEGIN, {"scenario": S1, "seed": 99})
	await tree.process_frame
	await tree.process_frame
	t.eq(Game.state.game_seed, 99)
	t.eq(Game.state.turn, 1, "old confirmation cannot resolve the new session")
	t.ok(Overlay.top() != null and Overlay.top().name == "TurnReport", "new session keeps its opening report")
	await _stop(app)

func test_report_does_not_repeat_when_returning_from_settings(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	app.go(AppRoot.SETTINGS, {"back": AppRoot.GAME})
	app.go(AppRoot.GAME)
	await tree.process_frame
	await tree.process_frame
	t.eq(Overlay.stack_size(), 0, "return to the same session does not reopen the report")
	await _stop(app)

func test_leaving_event_releases_voice_scope(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	var guard: int = 0
	while Events.pending_for(Game.view(), Game.state.player_id).is_empty() and guard < 12:
		Game.end_turn()
		guard += 1
	(app.screen as GameScreen).next_event()
	t.ok(Overlay.top() != null and Overlay.top().name == "EventOverlay", "fixture opens a pending event")
	var updates: Array[Dictionary] = []
	var observe: Callable = func(update: Dictionary) -> void: updates.append(update)
	VoiceService.changed.connect(observe)
	app.go(AppRoot.TITLE)
	await tree.process_frame
	VoiceService.changed.disconnect(observe)
	var stopped: bool = false
	for update: Dictionary in updates:
		if update.get("status") == "stopped": stopped = true
	t.ok(stopped, "leaving the event releases its voice scope")
	await _stop(app)

func test_repeated_pending_event_opens_only_one_modal(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	var guard: int = 0
	while Events.pending_for(Game.view(), Game.state.player_id).is_empty() and guard < 12:
		Game.end_turn()
		guard += 1
	var screen: GameScreen = app.screen as GameScreen
	screen.next_event()
	screen.next_event()
	t.eq(Overlay.stack_size(), 1, "repeated event dispatch must not stack the same blocking choice")
	await _stop(app)

func test_repeated_end_turn_opens_one_checklist(t: T) -> void:
	var app: AppRoot = await _start()
	Overlay.close_all()
	var screen: GameScreen = app.screen as GameScreen
	screen.end_turn()
	screen.end_turn()
	t.eq(Overlay.stack_size(), 1, "repeated End Turn must not stack checklists")
	await _stop(app)
