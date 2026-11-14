extends Node
## Research fixtures: PC and simulated phone 200% on private Xvfb.
const OUT: String = "/workspace/starfire-evidence/m2e/captures"
var root: Window
func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()
func _frames(n: int = 8) -> void:
	for i: int in n: await get_tree().process_frame
func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var path: String = OUT.path_join(name + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("Could not save " + path)
		get_tree().quit(1)
	print("capture: " + path)
func _run() -> void:
	var settings: Node = root.get_node("Settings")
	var layout: Node = root.get_node("Layout")
	var overlay: Node = root.get_node("Overlay")
	settings.set("persist", false)
	settings.call("set_reduce_motion", true)
	settings.call("set_hints_enabled", false)
	var app: AppRoot = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate() as AppRoot
	root.add_child(app)
	await _frames()
	for profile: String in ["desktop100", "phone200"]:
		var phone: bool = profile == "phone200"
		root.size = Vector2i(2400, 1080) if phone else Vector2i(1920, 1080)
		settings.call("set_text_scale", 2.0 if phone else 1.0)
		layout.call("set_profile", 2 if phone else 1)
		settings.call("set_view_mode", "command")
		settings.call("set_appearance", "strategic")
		await _frames()
		var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
		state.turn = 2
		var e: Empire = state.player()
		e.branch("physics").progress = 1234
		var selected: ResearchBranch = e.branch("society")
		selected.card = selected.hand[0]
		selected.progress = Research.cost(state, e, selected.card).total + 100
		var mod: Modifier = Modifier.new()
		mod.id = "fixture_no_research"
		mod.empire_id = e.id
		mod.source_key = "event.m2a_halden.1.title"
		mod.effects = [{"key": "research_bp:all", "value": -9000}] as Array[Dictionary]
		mod.turns_left = 10
		state.modifiers[mod.id] = mod
		overlay.call("close_all")
		app.go(AppRoot.CONTINUE, {"state": state})
		await _frames(12)
		overlay.call("close_all")
		var screen: GameScreen = app.screen as GameScreen
		screen.show_view(GameScreen.RESEARCH)
		await _frames(10)
		var bank: Control = screen.find_child("ResearchBank_physics", true, false) as Control
		var funded: Control = screen.find_child("ResearchEta_society", true, false) as Control
		if bank == null or funded == null:
			printerr("Missing research fixture control")
			get_tree().quit(1)
			return
		screen._scroll.ensure_control_visible(bank)
		await _shot(profile + "_banked")
		screen._scroll.ensure_control_visible(funded)
		await _shot(profile + "_funded_zero_rate")
	overlay.call("close_all")
	app.queue_free()
	var game: Node = root.get_node("Game")
	game.set("state", null)
	game.set("queue", null)
	game.set("last_result", null)
	await _frames(8)
	print("Direct fixture rendering only; not manual play.")
	root.get_node("Audio").call("quit_gracefully")
