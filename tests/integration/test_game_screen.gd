extends RefCounted
## The game screen (§7): it opens on Scenario 1 with the first orders, the advisor walks the first
## steps, orders are given from the views (with previews and reasons), End Turn shows its checklist
## and then the report and the events, and every view and overlay passes the explanation and layout
## audit on a PC and a phone at 100% and 200% text. Headless, like test_flow_screens.gd.

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


class SaveGate:
	extends RefCounted
	signal released
	var answer: bool = false
	func verify(_path: String, _written: String) -> bool:
		await released
		return answer


func test_manual_browser_confirmation_waits_and_guards_session(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var gs: GameScreen = app.screen as GameScreen
	Overlay.close_all()
	var current: GameState = Game.state
	var session: int = Game.session_serial
	var gate: SaveGate = SaveGate.new()
	gs._manual_save_pending = true
	gs._confirm_manual_save(current, session, "fixture", "fixture", gate.verify)
	gs.open_menu()
	var button: BaseButton = Overlay.root.find_child("Menu_save", true, false) as BaseButton
	t.ok(button != null and button.disabled, "save action is disabled during browser confirmation")
	t.eq(Overlay._toast_box.get_child_count(), 0, "save success is not announced before confirmation")
	gate.answer = true
	gate.released.emit()
	await _frames(2)
	t.not_ok(gs._manual_save_pending)
	t.not_ok(button.disabled, "the open menu permits another save after confirmation")
	var found: bool = false
	for toast: Node in Overlay._toast_box.get_children():
		if toast is Toast and (toast as Toast).text() == Strings.fmt("ui.game.saved"): found = true
	t.ok(found, "success is announced only after confirmation")
	Overlay.close_all()
	gate = SaveGate.new()
	gs._manual_save_pending = true
	gs._confirm_manual_save(current, session, "fixture", "fixture", gate.verify)
	Game.new_game(S1, 3)
	gate.released.emit()
	await _frames(2)
	t.eq(Overlay._toast_box.get_child_count(), 0, "a stale save callback cannot report into the new session")
	await _stop(app)


func test_game_facade_refuses_foreign_empire_orders(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var s: GameState = TinyState.build()
	var c: Colony = Colony.new()
	c.id = s.next_id("col")
	c.owner_id = "emp_meridian"
	c.planet_id = "pl_brume"
	c.pops = 1
	s.colonies[c.id] = c
	s.planets[c.planet_id].colony_id = c.id
	Game.resume(s)
	var order: Command = RenameColonyCommand.create(c.owner_id, c.id, "Foreign")
	t.ok(order.validate(s).ok, "foreign order is otherwise valid for that empire")
	var submitted: Result = Game.submit(order)
	t.not_ok(submitted.ok, "player facade rejects a foreign actor")
	t.eq(submitted.reason_key, "error.command.not_player")
	t.eq(Game.queue.size(), 0)
	await _stop(app)


func test_autosave_failure_warns_after_turn(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var old_dir: String = SaveService.dir
	var blocker: String = "user://test_autosave_block_%d" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(blocker, FileAccess.WRITE)
	f.store_string("not a directory")
	f.close()
	SaveService.dir = blocker
	Settings.persist = true
	var gs: GameScreen = app.screen as GameScreen
	Overlay.close_all()
	var before: int = Game.state.turn
	gs.resolve_turn(Game.state)
	Settings.persist = false
	await _frames(3)
	t.eq(Game.state.turn, before + 1, "the turn resolves despite the save error")
	var found: bool = false
	for toast: Node in Overlay._toast_box.get_children():
		if toast is Toast and (toast as Toast).text() == Strings.fmt("ui.game.autosave_failed"):
			found = true
	t.ok(found, "automatic save failure remains visible after opening the turn report")
	Overlay.clear_toasts()
	await _frames(2)
	var failed_attempt: int = SaveService._save_attempt
	SaveService._save_attempt += 1
	SaveService._notify_autosave_failure(Game.session_serial, failed_attempt)
	t.eq(Overlay._toast_box.get_child_count(), 0, "a newer save attempt suppresses an old warning")
	SaveService._notify_autosave_failure(Game.session_serial - 1, SaveService._save_attempt)
	t.eq(Overlay._toast_box.get_child_count(), 0, "an old session cannot warn over a new one")
	SaveService.dir = old_dir
	DirAccess.remove_absolute(blocker)
	await _stop(app)


func test_old_advisor_callback_cannot_submit_into_new_session(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var old_screen: GameScreen = app.screen as GameScreen
	Game.new_game(S1, 3)
	var before: int = Game.queue.size()
	old_screen._acknowledge({"id": "t_report"})
	t.eq(Game.queue.size(), before, "advisor callback from old session cannot queue into new game")
	await _stop(app)


func test_end_turn_guards_terminal_reentrancy_and_stale_confirmation(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var gs: GameScreen = app.screen as GameScreen
	Overlay.close_all()
	var before: GameState = Game.state
	var initial_turn: int = before.turn
	var nested: Array[TurnResult] = []
	var callback: Callable = func(_r: TurnResult) -> void: nested.append(Game.end_turn())
	Game.turn_resolved.connect(callback)
	gs.resolve_turn(before)
	Game.turn_resolved.disconnect(callback)
	t.eq(Game.state.turn, initial_turn + 1, "one confirmation advances one turn")
	t.eq(nested.size(), 1)
	t.ok(nested[0] == null, "a synchronous turn-resolved listener cannot resolve another turn")
	var current: GameState = Game.state
	gs.resolve_turn(before)
	t.ok(Game.state == current, "a stale confirmation cannot advance the next turn")
	Game._continuation_saving = true
	t.ok(Game.end_turn() == null, "turns are blocked while continuation persistence is pending")
	Game._continuation_saving = false
	Game.state.outcome = GameState.OUTCOME_WON
	var won_turn: int = Game.state.turn
	t.ok(Game.end_turn() == null, "a terminal game cannot advance")
	t.eq(Game.state.turn, won_turn)
	await _stop(app)


func test_a_game_opens_with_orders_and_plays_a_turn(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var gs: GameScreen = app.screen as GameScreen
	t.ok(gs != null, "Begin opens the game screen")
	if gs == null:
		await _stop(app)
		return
	t.ok(gs.find_child("TopBar", true, false) != null, "the top bar is there")
	t.ok(gs.find_child("Nav_colony", true, false) != null, "PC has a navigation rail")
	t.ok(gs.find_child("PlannerGrid", true, false) != null, "the colony planner is the first view")
	var report: Node = _root.get_node("Overlay").call("top")
	t.ok(report != null and report.name == "TurnReport", "the first report opens over the game")
	t.ok(gs.find_child("AdvisorCard", true, false) != null, "the advisor shows the first step")
	t.not_ok(Tutorial.is_done(Game.view(), "t_report"), "the report step waits for the report to be closed")
	(report as OverlayLayer).close()
	await _frames(3)
	t.ok(Tutorial.is_done(Game.view(), "t_report"), "closing the report completes its step")
	t.eq(DictIO.str_of(Tutorial.current(Game.view()), "id"), "t_food", "the next step follows")
	var chip: ResourceChip = gs.find_child("Chip_Food", true, false) as ResourceChip
	t.ok(chip != null, "the food chip is in the top bar")
	chip.open_pinned()
	await _frames(3)
	t.ok(Tutorial.is_done(Game.view(), "t_food"), "opening the food breakdown completes its step")
	# End Turn at once: the checklist lists what has no orders, and can be waved through.
	gs.end_turn()
	await _frames(3)
	var check: Node = _root.get_node("Overlay").call("top")
	t.ok(check != null and check.name == "EndTurnChecklist", "End Turn lists what still wants orders")
	var turn_before: int = Game.state.turn
	await _click(check, "EndAnyway")
	await _frames(4)
	t.eq(Game.state.turn, turn_before + 1, "ending the turn anyway plays it")
	var next: Node = _root.get_node("Overlay").call("top")
	t.ok(next != null and next.name == "TurnReport", "the turn's report opens")
	await _stop(app)


func test_orders_are_given_from_the_views(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var gs: GameScreen = app.screen as GameScreen
	_root.get_node("Overlay").call("close_all")
	var e: Empire = Game.view().player()
	var c: Colony = Game.view().colonies[gs.colony_id]
	# The planner: choose a free slot and a farm; the preview says what it would change.
	var free: Array[int] = ColonyRules.free_slots(c, Game.view().planets[c.planet_id])
	t.ok(not free.is_empty(), "Aster has a free slot")
	gs.select_slot(free[0])
	gs.set_pick("district", "agriculture")
	await _frames(3)
	t.ok(gs.find_child("Preview", true, false) != null, "the planner previews what a farm would change")
	var before: int = c.queue.size()
	await _click(gs, "Build")
	await _frames(3)
	t.eq(Game.view().colonies[c.id].queue.size(), before + 1, "Build queues the district")
	# The advisor's step completes on the state.
	t.ok(Tutorial.is_done(Game.view(), "t_farm") or DictIO.str_of(Tutorial.current(Game.view()), "id") != "t_farm", "queueing a farm completes its step")
	# Undo takes it back.
	await _click(gs, "Undo")
	await _frames(3)
	t.eq(Game.view().colonies[c.id].queue.size(), before, "Undo takes the last order back")
	# Research: pick a card from the first branch's hand.
	gs.show_view(GameScreen.RESEARCH)
	await _frames(3)
	var hand: Array[String] = e.research["society"].hand
	t.ok(not hand.is_empty(), "society offers cards")
	await _click(gs, "Pick_" + hand[0])
	await _frames(3)
	t.eq(Game.view().player().research["society"].card, hand[0], "picking a card studies it")
	# The system: survey Brume with the probe.
	gs.open_planet("pl_brume")
	await _frames(3)
	var survey: Node = gs.find_child("PlanetPanel", true, false)
	t.ok(survey != null, "the planet's panel opens")
	var probe: Ship = null
	for sh: Ship in Game.view().ships_of(e.id):
		if Ships.role(sh) == Ships.ROLE_SURVEY:
			probe = sh
	await _click(gs, "Survey_" + probe.id)
	await _frames(3)
	t.ok(Game.view().ships[probe.id].is_busy(), "the probe is surveying")
	# An ordinance: the Festival, if the price allows.
	gs.show_view(GameScreen.ORDINANCES)
	await _frames(3)
	t.ok(gs.find_child("Ordinance_festival", true, false) != null, "the Festival is offered")
	# The galaxy: the neighbours are fogged and the lanes locked.
	gs.show_view(GameScreen.GALAXY)
	await _frames(3)
	t.ok(gs.find_child("GalaxyMap", true, false) != null and gs.find_child("LockedNote", true, false) != null, "the galaxy says why the lanes are locked")
	await _stop(app)


func test_events_open_after_the_report_and_block_end_turn(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	var gs: GameScreen = app.screen as GameScreen
	_root.get_node("Overlay").call("close_all")
	# Play until Scenario 1's first scripted event (the Labor Strike, turn 5) is waiting.
	var guard: int = 0
	while Events.pending_for(Game.view(), Game.view().player_id).is_empty() and guard < 12:
		Game.end_turn()
		guard += 1
	t.ok(not Events.pending_for(Game.view(), Game.view().player_id).is_empty(), "an event is waiting after a few turns")
	gs.end_turn()
	await _frames(4)
	var ov: Node = _root.get_node("Overlay").call("top")
	t.ok(ov != null and ov.name == "EventOverlay", "End Turn opens the event instead of ending the turn")
	if ov == null or ov.name != "EventOverlay":
		await _stop(app)
		return
	var turn: int = Game.state.turn
	var choice: Node = ov.find_child("Choice_0", true, false)
	t.ok(choice != null, "the event offers its choices")
	await _click(ov, "Choice_0")
	await _frames(4)
	t.ok(Events.pending_for(Game.view(), Game.view().player_id).is_empty() or _root.get_node("Overlay").call("top") != ov, "answering the event moves on")
	t.eq(Game.state.turn, turn, "an answer is an order: the turn has not ended")
	await _stop(app)


func test_every_view_and_overlay_passes_the_audit(t: T) -> void:
	for prof: Array in PROFILES:
		var app: AppRoot = await _start(prof, 3)
		var gs: GameScreen = app.screen as GameScreen
		var label: String = "%s %s text %d%%" % [prof[0], "phone" if prof[1] else "pc", int(float(prof[2]) * 100)]
		await _audit(t, label + " game with the first report")
		_root.get_node("Overlay").call("close_all")
		for state_name: String in ["colony", "slot", "system", "planet", "research", "ordinances", "objectives", "galaxy", "checklist", "menu", "more"]:
			await gs.demo(state_name)
			await _audit(t, "%s %s" % [label, state_name])
		# A game some turns in: colonies, queues, cards and a governor.
		var mid: GameState = _mid_game()
		Game.resume(mid)
		app.go(AppRoot.GAME)
		await _frames(4)
		gs = app.screen as GameScreen
		_root.get_node("Overlay").call("close_all")
		for state_name2: String in ["colony", "slot", "system", "research", "ordinances", "market", "objectives", "why"]:
			await gs.demo(state_name2)
			await _audit(t, "%s mid-game %s" % [label, state_name2])
		await _stop(app)


func test_settings_load_and_credits_screens(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 3)
	_root.get_node("Overlay").call("close_all")
	app.go(AppRoot.SETTINGS, {"back": AppRoot.GAME})
	await _frames(3)
	t.eq(app.route, AppRoot.SETTINGS)
	await _audit(t, "settings")
	var music: HSlider = app.screen.find_child("Slider_music_volume", true, false) as HSlider
	t.ok(music != null, "settings has a music slider")
	music.value = 0.35
	await _frames(2)
	t.near(_root.get_node("Settings").get("music_volume"), 0.35, 0.001, "the slider sets the music volume")
	_root.get_node("Settings").call("set_music_volume", 0.7)
	await _press(app, "Back")
	t.eq(app.route, AppRoot.GAME, "Back returns to the game")
	app.go(AppRoot.LOAD, {"back": AppRoot.GAME})
	await _frames(3)
	t.eq(app.route, AppRoot.LOAD)
	await _audit(t, "load")
	app.go(AppRoot.CREDITS, {"back": AppRoot.TITLE})
	await _frames(3)
	var credits: RichTextLabel = app.screen.find_child("CreditsText", true, false) as RichTextLabel
	t.ok(credits != null and credits.text.contains("Godot"), "the credits show the file")
	await _audit(t, "credits")
	await _stop(app)


# --- helpers ------------------------------------------------------------------------------------

## Scenario 1 played by the balanced bot to turn 24: colonies, queues, cards, orders.
func _mid_game() -> GameState:
	return BotRunner.run(Content.db(), S1, "balanced", 3, 24).final_state


func _start(prof: Array, game_seed: int) -> AppRoot:
	_tree = Engine.get_main_loop() as SceneTree
	_root = _tree.root
	var settings: Node = _root.get_node("Settings")
	settings.set("persist", false)
	settings.call("set_reduce_motion", true)
	settings.call("set_hints_enabled", true)
	_root.size = prof[0]
	settings.call("set_text_scale", float(prof[2]))
	_root.get_node("Layout").call("set_profile", 2 if prof[1] else 1)
	GameScreen._opened_session = -1
	var app: AppRoot = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	_root.add_child(app)
	await _frames(3)
	app.go(AppRoot.BRIEFING, {"scenario": S1})
	await _frames(3)
	app.go(AppRoot.BEGIN, {"seed": game_seed})
	await _frames(5)
	return app


func _stop(app: AppRoot) -> void:
	_root.get_node("Overlay").call("close_all")
	app.queue_free()
	var game: Node = _root.get_node("Game")
	game.set("state", null)
	game.set("queue", null)
	game.set("last_result", null)
	await _frames(1)
	_root.get_node("Settings").call("set_text_scale", 1.0)
	_root.get_node("Layout").call("set_profile", 0)


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## Presses a button by name; a named container (an order button with its reason) gives its first
## button.
func _click(under: Node, node_name: String) -> void:
	var n: Node = under.find_child(node_name, true, false)
	var b: BaseButton = n as BaseButton
	if b == null and n != null:
		for c: Node in n.find_children("*", "BaseButton", true, false):
			b = c as BaseButton
			break
	if b == null:
		push_error("no button named %s" % node_name)
		return
	if b.disabled:
		push_error("button %s is disabled" % node_name)
		return
	if b.toggle_mode:
		b.button_pressed = true
	b.pressed.emit()
	await _frames(3)


func _press(app: AppRoot, button_name: String) -> void:
	await _click(app.screen, button_name)


func _audit(t: T, label: String) -> void:
	await _frames(4)
	var view: Rect2 = Rect2(Vector2.ZERO, _root.get_node("Layout").get("logical_size"))
	var rep: IdAudit.AuditReport = IdAudit.run(_root, _root.get_node("Overlay").get("root"), view, _root.get_node("Layout").get("touch_ui"))
	t.ok(rep.checked_labels >= 3, "%s: audited %d labels" % [label, rep.checked_labels])
	for issue: Dictionary in rep.issues.slice(0, 6):
		t.fail("%s: %s %s | %s | %s" % [label, issue["rule"], issue["detail"], issue["text"], issue["path"]])


func test_preview_travel_controls_and_stale_callback(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 1)
	app.go(AppRoot.BRIEFING, {"scenario": "m2a_expedition"})
	await _frames(3)
	app.go(AppRoot.BEGIN, {"seed": 1})
	await _frames(4)
	Overlay.close_all()
	var gs: GameScreen = app.screen as GameScreen
	Settings.set_appearance("strategic")
	gs.show_view(GameScreen.GALAXY)
	await _frames(3)
	t.ok(gs.find_child("FleetTravel", true, false) != null, "strategic map offers travel")
	gs.open_travel()
	await _frames(3)
	var drawer: Drawer = Overlay.top() as Drawer
	t.ok(drawer != null, "travel drawer opens")
	var move: BaseButton = drawer.find_child("Move_flt_0001_sys_tessel", true, false) as BaseButton if drawer != null else null
	t.ok(move != null, "reachable unknown system offers a move")
	if move != null:
		move.pressed.emit()
		t.eq(Game.view().fleets["flt_0001"].path, ["sys_tessel"] as Array[String], "button queues selected fleet and destination")
		Game.undo()
		Overlay.close_all()
		await _frames(4)
		gs.open_travel()
		await _frames(3)
		drawer = Overlay.top() as Drawer
		move = drawer.find_child("Move_flt_0001_sys_tessel", true, false) as BaseButton
		t.ok(move != null, "undo restores the move choice")
		var old_serial: int = Game.session_serial
		Game.new_game("m2a_expedition", 1)
		t.ok(Game.session_serial != old_serial)
		if move != null: move.pressed.emit()
		t.eq(Game.queue.size(), 0, "stale drawer callback cannot order a new session")
	Overlay.close_all()
	gs.planet_id = "pl_aster"
	gs.jump("system", "sys_vesper")
	t.eq(gs.system_id, "sys_vesper", "arrival report opens the destination")
	t.eq(gs.planet_id, "", "arrival report clears the previous planet selection")
	Settings.set_appearance("3d")
	Settings.set_view_mode("immersive")
	gs.show_view(GameScreen.SYSTEM)
	await _frames(4)
	t.ok(gs.find_child("FleetTravel", true, false) != null, "immersive 3D system offers travel")
	Settings.set_view_mode("command")
	await _stop(app)


func test_preview_cache_choices_render_and_stale_choice_is_safe(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 1)
	app.go(AppRoot.BRIEFING, {"scenario": "m2a_expedition"})
	await _frames(3)
	app.go(AppRoot.BEGIN, {"seed": 1})
	await _frames(4)
	Overlay.close_all()
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	state.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
	state.turn = 2
	Events.run(state, TurnResult.new())
	app.go(AppRoot.CONTINUE, {"state": state})
	await _frames(4)
	var modal: Modal = Overlay.top() as Modal
	t.ok(modal != null and modal.name == "EventOverlay", "Gate decision opens in the event overlay")
	if modal != null:
		var first: Node = modal.find_child("Choice_0", true, false)
		var second: Node = modal.find_child("Choice_1", true, false)
		var third: Node = modal.find_child("Choice_2", true, false)
		t.ok(first != null and second != null and third != null, "all three options render")
		if first != null and second != null:
			t.ok(first.find_child("Cost_energy", true, false) != null, "salvage cost is visible")
			t.ok(second.find_child("Cost_energy", true, false) != null, "study cost is visible")
			t.ok(first.find_children("*", "EffectList", true, false).size() > 0, "salvage effect is visible")
			t.ok(second.find_children("*", "EffectList", true, false).size() > 0, "study effect is visible")
			var buttons: Array[Node] = first.find_children("*", "BaseButton", true, false)
			var button: BaseButton = buttons[0] as BaseButton if not buttons.is_empty() else null
			Game.new_game("m2a_expedition", 1)
			if button != null: button.pressed.emit()
			t.eq(Game.queue.size(), 0, "stale event choice cannot order a new session")
	await _stop(app)


func test_preview_auto_explore_toggle_uses_command_bus(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 1)
	app.go(AppRoot.BRIEFING, {"scenario": "m2a_expedition"})
	await _frames(3)
	app.go(AppRoot.BEGIN, {"seed": 1})
	await _frames(4)
	Overlay.close_all()
	var gs: GameScreen = app.screen as GameScreen
	gs.show_view(GameScreen.GALAXY)
	gs.open_travel()
	await _frames(3)
	var drawer: Drawer = Overlay.top() as Drawer
	var toggle: BaseButton = drawer.find_child("AutoExplore_flt_0002", true, false) as BaseButton
	t.ok(toggle != null and not toggle.disabled, "survey fleet offers automation")
	if toggle != null:
		toggle.pressed.emit()
		t.ok(AutoExplore.enabled(Game.view(), "flt_0002"), "toggle submits intent through the command queue")
		Game.end_turn()
		await _frames(4)
		var fleet: Fleet = Game.view().fleets["flt_0002"]
		var route: Array[String] = fleet.path.duplicate()
		gs.open_travel()
		await _frames(3)
		drawer = Overlay.top() as Drawer
		toggle = drawer.find_child("AutoExplore_flt_0002", true, false) as BaseButton
		t.ok(toggle != null and not toggle.disabled, "automation can be stopped while in transit")
		if toggle != null:
			toggle.pressed.emit()
			t.not_ok(AutoExplore.enabled(Game.view(), "flt_0002"), "stop changes intent")
			t.eq(Game.view().fleets["flt_0002"].path, route, "stop keeps the current journey")
	await _stop(app)


func test_preview_empty_gate_system_copy_and_beacon(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 1)
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	state.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
	state.turn = 2
	Settings.set_appearance("strategic")
	app.go(AppRoot.CONTINUE, {"state": state})
	await _frames(4)
	Overlay.close_all()
	var gs: GameScreen = app.screen as GameScreen
	gs.jump("system", "sys_halden")
	await _frames(3)
	for mode: String in ["strategic", "3d"]:
		Settings.set_appearance(mode)
		await _frames(4)
		var no_planets: bool = false
		var beacon: bool = false
		var invalid_hint: bool = false
		for label: Node in gs.find_children("*", "Label", true, false):
			var content: String = (label as Label).text
			if content == Strings.fmt("ui.system.no_planets"): no_planets = true
			if content == Strings.fmt("ui.system.beacon_dormant"): beacon = true
			if content == Strings.fmt("ui.system.pick_hint"): invalid_hint = true
		t.ok(no_planets, mode + " explains an empty system")
		t.ok(beacon, mode + " names the dormant beacon")
		if mode == "strategic":
			var beacon_label: Label = gs.find_child("SystemBeacon", true, false) as Label
			t.ok(beacon_label != null and beacon_label.size.x >= beacon_label.get_minimum_size().x, "beacon caption has room to read")
			if beacon_label != null: t.eq(beacon_label.get_line_count(), 1, "desktop beacon caption does not wrap per character")
		t.not_ok(invalid_hint, mode + " does not ask for a nonexistent planet")
	await _stop(app)


func test_preview_stop_fleet_order_and_undo_in_both_map_modes(t: T) -> void:
	for profile_index: int in [0, 3]:
		var app: AppRoot = await _start(PROFILES[profile_index], 1)
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		state.player().known_systems["sys_tessel"] = Empire.FOG_SURVEYED
		var fleet: Fleet = state.fleets["flt_0002"]
		fleet.path = ["sys_tessel", "sys_halden"] as Array[String]
		fleet.move_progress = 1
		AutoExplore.set_enabled(state, state.player_id, fleet.id, true)
		Settings.set_appearance("strategic" if profile_index == 0 else "3d")
		Settings.set_view_mode("command" if profile_index == 0 else "immersive")
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(5)
		Overlay.close_all()
		var gs: GameScreen = app.screen as GameScreen
		gs.show_view(GameScreen.GALAXY)
		await _frames(3)
		t.ok(gs.find_child("FleetTravel", true, false) != null, "map mode exposes shared fleet drawer")
		gs.open_travel()
		await _frames(3)
		var drawer: Drawer = Overlay.top() as Drawer
		var button: BaseButton = drawer.find_child("StopFleet_flt_0002", true, false) as BaseButton if drawer != null else null
		t.ok(button != null and not button.disabled, "stop order is offered for an active multileg route")
		if button != null:
			var original_eta: int = Travel.remaining_eta(Game.view(), fleet.id).total
			var expected: GameState = state.clone()
			Travel.stop_next(expected, fleet.id)
			var expected_eta: int = Travel.remaining_eta(expected, fleet.id).total
			button.pressed.emit()
			t.eq(Game.view().fleets[fleet.id].path, ["sys_tessel"] as Array[String], "only the current leg remains")
			t.eq(Game.view().fleets[fleet.id].move_progress, 1, "stop preserves progress")
			t.not_ok(AutoExplore.enabled(Game.view(), fleet.id), "stop clears auto-explore")
			t.eq(Travel.remaining_eta(Game.view(), fleet.id).total, expected_eta, "remaining ETA follows the retained leg")
			t.ok(expected_eta < original_eta, "removed leg no longer contributes to ETA")
			await _frames(4)
			gs.open_travel()
			await _frames(3)
			drawer = Overlay.top() as Drawer
			var fleet_card: Node = drawer.find_child("Fleet_flt_0002", true, false) if drawer != null else null
			var destination_visible: bool = false
			var eta_visible: bool = false
			if fleet_card != null:
				for item: Node in fleet_card.find_children("*", "Label", true, false):
					if (item as Label).text == Strings.fmt("ui.travel.en_route", {"system": Strings.fmt("system.tessel.name")}): destination_visible = true
				for item: Node in fleet_card.find_children("*", "Explainable", true, false):
					var explanation: Explainable = item as Explainable
					if explanation.breakdown != null and explanation.breakdown.label_key == "breakdown.travel_turns" and explanation.breakdown.total == expected_eta: eta_visible = true
			t.ok(destination_visible, "drawer shows the revised destination")
			t.ok(eta_visible, "drawer exposes the revised simulation ETA as an Explainable")
			Overlay.close_all()
			Game.undo()
			t.eq(Game.view().fleets[fleet.id].path, ["sys_tessel", "sys_halden"] as Array[String], "undo restores route")
			t.eq(Game.view().fleets[fleet.id].move_progress, 1, "undo preserves original progress")
			t.ok(AutoExplore.enabled(Game.view(), fleet.id), "undo restores auto-explore")
			Overlay.close_all()
			await _frames(4)
			gs.open_travel()
			await _frames(3)
			drawer = Overlay.top() as Drawer
			button = drawer.find_child("StopFleet_flt_0002", true, false) as BaseButton
			t.ok(button != null, "undo restores stop action")
			Game.new_game("m2a_expedition", 1)
			if button != null: button.pressed.emit()
			t.eq(Game.queue.size(), 0, "stale stop callback cannot affect a new session")
		Settings.set_view_mode("command")
		await _stop(app)


func test_preview_stop_fleet_unknown_next_and_single_leg_auto(t: T) -> void:
	var app: AppRoot = await _start(PROFILES[0], 1)
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	state.turn = 2
	var fleet: Fleet = state.fleets["flt_0002"]
	fleet.path = ["sys_vesper"] as Array[String]
	fleet.move_progress = 1
	AutoExplore.set_enabled(state, state.player_id, fleet.id, true)
	app.go(AppRoot.CONTINUE, {"state": state})
	await _frames(5)
	Overlay.close_all()
	var gs: GameScreen = app.screen as GameScreen
	gs.show_view(GameScreen.GALAXY)
	gs.open_travel()
	await _frames(3)
	var drawer: Drawer = Overlay.top() as Drawer
	var card: Node = drawer.find_child("Fleet_flt_0002", true, false) if drawer != null else null
	t.ok(card != null, "survey fleet is listed")
	if card != null:
		var has_unknown: bool = false
		var leaked: bool = false
		for label: Node in card.find_children("*", "Label", true, false):
			var content: String = (label as Label).text
			if content == Strings.fmt("ui.travel.stop_at", {"system": Strings.fmt("ui.travel.unknown", {"number": str(DictIO.sorted_keys(state.systems).find("sys_vesper") + 1)})}): has_unknown = true
			if content.contains(Strings.fmt("system.vesper.name")): leaked = true
		t.ok(has_unknown, "next system uses the numbered unknown label")
		t.not_ok(leaked, "undiscovered destination name is not disclosed")
		var button: BaseButton = card.find_child("StopFleet_flt_0002", true, false) as BaseButton
		t.ok(button != null and not button.disabled, "single-leg fleet with automation can stop at arrival")
		if button != null:
			button.pressed.emit()
			t.eq(Game.view().fleets[fleet.id].path, ["sys_vesper"] as Array[String], "current leg remains")
			t.not_ok(AutoExplore.enabled(Game.view(), fleet.id), "stopping prevents another automatic assignment")
			Game.end_turn()
			await _frames(4)
			Overlay.close_all()
			gs.open_travel()
			await _frames(3)
			drawer = Overlay.top() as Drawer
			card = drawer.find_child("Fleet_flt_0002", true, false) if drawer != null else null
			button = card.find_child("StopFleet_flt_0002", true, false) as BaseButton if card != null else null
			t.ok(button != null and button.disabled, "single-leg fleet already stopping cannot repeat stop")
	await _stop(app)


func test_shroud_giant_outpost_choices_in_both_map_modes(t: T) -> void:
	for profile_index: int in [0, 3]:
		var app: AppRoot = await _start(PROFILES[profile_index], 1)
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		state.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
		state.player().surveyed_planets.append("pl_shroud_giant")
		state.fleets["flt_0001"].system_id = "sys_shroud"
		Settings.set_view_mode("command")
		Settings.set_appearance("strategic" if profile_index == 0 else "3d")
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(5)
		Overlay.close_all()
		var gs: GameScreen = app.screen as GameScreen
		gs.open_planet("pl_shroud_giant")
		await _frames(4)
		for kind: String in ["energy", "research"]:
			var action: Node = gs.find_child("Outpost_" + kind, true, false)
			t.ok(action != null, "gas giant offers %s outpost in this map mode" % kind)
			if action == null: continue
			var buttons: Array[Node] = action.find_children("*", "BaseButton", true, false)
			var button: BaseButton = buttons[0] as BaseButton if not buttons.is_empty() else null
			t.ok(button != null and not button.disabled, "outpost choice is available")
			if button == null or button.disabled: continue
			button.pressed.emit()
			t.eq(Game.view().ships["shp_0001"].task_param, kind, "selected output is sent through the command bus")
			Game.undo()
			await _frames(4)
		await _stop(app)


func test_shroud_event_choices_visible_after_discovery(t: T) -> void:
	for profile_index: int in [0, 3]:
		var app: AppRoot = await _start(PROFILES[profile_index], 1)
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		state.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
		Events.run(state, TurnResult.new())
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(5)
		var modal: Modal = Overlay.top() as Modal
		t.ok(modal != null and modal.name == "EventOverlay", "Shroud discovery opens the event")
		if modal != null:
			var first: Node = modal.find_child("Choice_0", true, false)
			var second: Node = modal.find_child("Choice_1", true, false)
			var third: Node = modal.find_child("Choice_2", true, false)
			t.ok(first != null and second != null and third != null, "all three choices render")
			if first != null and second != null and third != null:
				t.ok(first.find_child("Cost_energy", true, false) != null, "hull recovery shows its energy cost")
				t.ok(second.find_child("Cost_energy", true, false) != null, "provisions show their energy cost")
				t.ok(third.find_child("Cost_energy", true, false) == null, "honouring the crew is free")
				for option: Node in [first, second, third]:
					t.ok(option.find_children("*", "EffectList", true, false).size() > 0, "choice reward is visible")
		await _stop(app)


func test_shroud_outpost_projection_without_builder_and_actual_output(t: T) -> void:
	for profile_index: int in [0, 3]:
		var app: AppRoot = await _start(PROFILES[profile_index], 1)
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		state.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
		state.player().surveyed_planets.append("pl_shroud_giant")
		var mod: Modifier = Modifier.new()
		mod.id = "mod_preview_test"
		mod.empire_id = state.player_id
		mod.source_key = "event.m2a_halden.1.title"
		mod.effects = [{"key": "research_bp:all", "value": 5000}] as Array[Dictionary]
		mod.turns_left = 10
		state.modifiers[mod.id] = mod
		Settings.set_view_mode("command")
		Settings.set_appearance("strategic" if profile_index == 0 else "3d")
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(4)
		Overlay.close_all()
		var gs: GameScreen = app.screen as GameScreen
		var original_hash: String = Game.view().state_hash()
		gs.open_planet("pl_shroud_giant")
		await _frames(4)
		await _audit(t, "Shroud outpost options in map mode at profile %d" % profile_index)
		var energy: Node = gs.find_child("OutpostProjection_energy", true, false)
		var research: Node = gs.find_child("OutpostProjection_research", true, false)
		t.ok(energy != null and research != null, "surveyed gas giant shows both options without a builder")
		t.ok(gs.find_child("Outpost_energy", true, false) == null, "no remote construction command is offered")
		if energy != null and research != null:
			var energy_net: Explainable = energy.find_child("OutpostNet_energy", true, false) as Explainable
			var energy_upkeep: Explainable = energy.find_child("OutpostUpkeep", true, false) as Explainable
			var expected_energy: Economy.ColonyReport = Economy.preview_outpost(state, state.player_id, "pl_shroud_giant", "energy")
			t.ok(energy_net != null and energy_net.breakdown.total == expected_energy.net["energy"].total, "energy net uses the simulation preview")
			t.ok(energy_upkeep != null and energy_upkeep.breakdown.total == Economy.outpost_upkeep().total, "upkeep is explicit and explainable")
			var expected_research: Economy.ColonyReport = Economy.preview_outpost(state, state.player_id, "pl_shroud_giant", "research")
			for branch: String in Empire.BRANCHES:
				var row: Explainable = research.find_child("OutpostResearch_" + branch, true, false) as Explainable
				t.ok(row != null and row.breakdown.total == expected_research.research[branch].total, "each research branch uses modifier-aware simulation output")
		t.eq(Game.view().state_hash(), original_hash, "opening previews does not mutate gameplay")
		var built: GameState = state.clone()
		var c: Colony = Colony.new()
		c.id = "col_preview_test"
		c.owner_id = built.player_id
		c.planet_id = "pl_shroud_giant"
		c.outpost_kind = "research"
		built.colonies[c.id] = c
		built.planets[c.planet_id].colony_id = c.id
		app.go(AppRoot.CONTINUE, {"state": built})
		await _frames(4)
		Overlay.close_all()
		gs = app.screen as GameScreen
		gs.open_planet("pl_shroud_giant")
		await _frames(4)
		var actual: Node = gs.find_child("OutpostActual", true, false)
		t.ok(actual != null, "owned outpost shows current output")
		if actual != null:
			var report: Economy.ColonyReport = Economy.colony(built, c)
			for branch: String in Empire.BRANCHES:
				var row: Explainable = actual.find_child("OutpostResearch_" + branch, true, false) as Explainable
				t.ok(row != null and row.breakdown.total == report.research[branch].total, "owned outpost shows actual branch output")
		await _stop(app)


func test_shroud_marker_remains_unnamed_until_discovered(t: T) -> void:
	for profile_index: int in [0, 3]:
		var app: AppRoot = await _start(PROFILES[profile_index], 1)
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		Settings.set_view_mode("command")
		Settings.set_appearance("strategic" if profile_index == 0 else "3d")
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(4)
		Overlay.close_all()
		var gs: GameScreen = app.screen as GameScreen
		gs.show_view(GameScreen.GALAXY)
		await _frames(4)
		var expected_number: String = str(DictIO.sorted_keys(state.systems).find("sys_shroud") + 1)
		t.eq(gs.system_label("sys_shroud"), Strings.fmt("ui.travel.unknown", {"number": expected_number}), "marker uses an unnamed position label")
		var marker: Node = gs.find_child("System_sys_shroud", true, false)
		t.ok(marker != null, "the unknown star remains selectable on the map")
		var leaked: bool = false
		if marker != null:
			if marker is Button and (marker as Button).text.contains(Strings.fmt("system.shroud.name")): leaked = true
			for label: Node in marker.find_children("*", "Label", true, false):
				if (label as Label).text.contains(Strings.fmt("system.shroud.name")): leaked = true
		t.not_ok(leaked, "the visible marker does not reveal its hidden name")
		var disclosed: GameState = state.clone()
		disclosed.player().known_systems["sys_shroud"] = Empire.FOG_SURVEYED
		app.go(AppRoot.CONTINUE, {"state": disclosed})
		await _frames(4)
		Overlay.close_all()
		gs = app.screen as GameScreen
		t.eq(gs.system_label("sys_shroud"), Strings.fmt("system.shroud.name"), "arrival reveals the system name")
		await _stop(app)


func _idle_probe_checks(state: GameState) -> int:
	var count: int = 0
	for item: ReportItem in GameModel.end_turn_checks(state, Economy.empire(state, state.player_id)):
		if item.text_key == "ui.endturn.ship_idle" and item.args.get("ship_key", "") == "hull.survey_probe.name": count += 1
	return count


func test_auto_explore_readiness_checks_keep_critical_events(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var fleet: Fleet = state.fleets["flt_0002"]
	var probe: Ship = state.ships[fleet.ship_ids[0]]
	t.eq(_idle_probe_checks(state), 1, "disabled idle probe still prompts for orders")
	AutoExplore.set_enabled(state, state.player_id, fleet.id, true)
	t.eq(_idle_probe_checks(state), 0, "enabled valid probe waiting for an assignment is not idle")
	state.player().known_systems["sys_halden"] = Empire.FOG_SURVEYED
	Events.run(state, TurnResult.new())
	var blocking: bool = false
	for item: ReportItem in GameModel.end_turn_checks(state, Economy.empire(state, state.player_id)):
		if item.text_key == "ui.endturn.event" and item.blocks_end_turn: blocking = true
	t.ok(blocking, "a pending decision remains a blocking checklist item")
	t.eq(_idle_probe_checks(state), 0, "an automated probe waiting on a decision is not called idle")
	AutoExplore.set_enabled(state, state.player_id, fleet.id, false)
	probe.task = Ship.TASK_SURVEY
	probe.task_target = "pl_aster"
	probe.task_turns = 1
	t.eq(_idle_probe_checks(state), 0, "a busy probe is not reported idle")
	probe.task = Ship.TASK_NONE
	probe.task_target = ""
	probe.task_turns = 0
	fleet.path = ["sys_vesper"] as Array[String]
	t.eq(_idle_probe_checks(state), 0, "a travelling probe is not reported idle")
	fleet.path.clear()
	AutoExplore.set_enabled(state, state.player_id, fleet.id, true)
	probe.design_id = "invalid_design"
	t.eq(_idle_probe_checks(state), 1, "invalid automation does not hide a genuinely idle probe")


func test_research_banked_progress_and_completion_estimate_in_both_layouts(t: T) -> void:
	for profile_index: int in [0, 3]:
		var app: AppRoot = await _start(PROFILES[profile_index], 1)
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		var empire: Empire = state.player()
		empire.branch("physics").progress = 1234
		var society: ResearchBranch = empire.branch("society")
		society.card = society.hand[0]
		society.progress = Research.cost(state, empire, society.card).total + 100
		var engineering: ResearchBranch = empire.branch("engineering")
		engineering.card = engineering.hand[0]
		engineering.progress = 0
		var mod: Modifier = Modifier.new()
		mod.id = "mod_no_research"
		mod.empire_id = empire.id
		mod.source_key = "event.m2a_halden.1.title"
		mod.effects = [{"key": "research_bp:all", "value": -9000}] as Array[Dictionary]
		mod.turns_left = 10
		state.modifiers[mod.id] = mod
		Settings.set_view_mode("command")
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(4)
		Overlay.close_all()
		var gs: GameScreen = app.screen as GameScreen
		gs.show_view(GameScreen.RESEARCH)
		await _frames(4)
		var bank: Explainable = gs.find_child("ResearchBank_physics", true, false) as Explainable
		t.ok(bank != null and bank.breakdown != null and bank.breakdown.total == 1234, "empty branch shows explainable banked research")
		if bank != null:
			var label: Label = bank.find_child("*", true, false) as Label
			t.ok(label != null and label.text == Strings.fmt("ui.research.banked", {"amount_c": 1234}), "bank label shows the stored amount")
		var rate: Explainable = gs.find_child("ResearchRate_society", true, false) as Explainable
		t.ok(rate != null and rate.breakdown.total == 0, "funded fixture has zero research income")
		var funded: Label = gs.find_child("ResearchEta_society", true, false) as Label
		t.ok(funded != null and funded.text == Strings.fmt("ui.research.completes_next"), "fully banked card completes next turn even at zero rate")
		var no_income: Label = gs.find_child("ResearchEta_engineering", true, false) as Label
		t.ok(no_income != null and no_income.text == Strings.fmt("ui.research.no_income"), "unfunded zero-rate card reports no income")
		await _audit(t, "research bank and funded estimate at profile %d" % profile_index)
		var normal: GameState = state.clone()
		normal.modifiers.erase(mod.id)
		normal.player().branch("society").progress = 0
		app.go(AppRoot.CONTINUE, {"state": normal})
		await _frames(4)
		Overlay.close_all()
		gs = app.screen as GameScreen
		gs.show_view(GameScreen.RESEARCH)
		await _frames(4)
		var eta: Label = gs.find_child("ResearchEta_society", true, false) as Label
		var turns: int = Research.turns_remaining(normal, normal.player_id, "society")
		t.ok(turns > 0 and eta != null and eta.text == Strings.fmt("ui.research.eta", {"turns": turns}), "normal estimate uses the simulation")
		await _stop(app)
