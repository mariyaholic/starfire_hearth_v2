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
	GameScreen._opened_seed = -1
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
