extends Node
## Stage G deterministic, command-bus First Light campaign. The AppRoot title/campaign/briefing,
## event choices, save/load, and debrief use production screens. Orders come from the shipped
## balanced BotPolicy and enter the same Game command queue as player orders; there are no fixtures.

const OUT: String = "res://build/stage_g/campaign"
const SCENARIO: String = "s1_first_light"
const GAME_SEED: int = 1
const MAX_TURNS: int = 120

class ErrorCatcher:
	extends Logger
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _traces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s" % [file, line, rationale if not rationale.is_empty() else code])
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func take() -> Array[String]:
		return errors.duplicate()

var checks: T = T.new()
var app: Variant
var game: Node
var captures: Array[String] = []
var milestones: Dictionary = {}
var command_counts: Dictionary = {}
var opening_counts: Dictionary = {}
var expected_hashes: Array[String] = []
var error_catcher: Logger
var root: Window
var save_slot: String = ""


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func _frames(count: int = 4) -> void:
	for i in count:
		await get_tree().process_frame


func _click(name: String, host: Node = null) -> void:
	var parent: Node = host if host != null else app.screen
	var target: Node = parent.find_child(name, true, false)
	if target == null:
		target = root.get_node("Overlay").get("root").find_child(name, true, false)
	var button: BaseButton = target as BaseButton
	if button == null and target != null:
		for child: Node in target.find_children("*", "BaseButton", true, false):
			button = child as BaseButton
			break
	checks.ok(button != null, "production control exists: " + name)
	if button == null:
		return
	checks.not_ok(button.disabled, "production control enabled: " + name)
	if button.disabled:
		return
	button.pressed.emit()
	await _frames(5)


func _toggle_layout(expected: String) -> void:
	var gs: Node = app.screen
	var button: Node = gs.find_child("ModeToggle", true, false)
	checks.ok(button is BaseButton, "production Command/Immersive layout control exists")
	if button is BaseButton:
		await _click("ModeToggle", gs)
	checks.eq(str(root.get_node("Settings").get("view_mode")), expected, "production layout control selects " + expected)


func _capture(name: String, close_overlays: bool = true, min_world_colors: int = 0) -> void:
	if close_overlays:
		root.get_node("Overlay").call("close_all")
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if min_world_colors > 0:
		var screen: Variant = app.screen
		var renderer: Variant = screen.world_controller.host.renderer if screen != null else null
		var unique: Dictionary = {}
		if renderer is ColonyRenderer:
			var bounds: Rect2i = Rect2i(renderer.get_global_rect())
			bounds = bounds.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			var sx: int = maxi(1, int(bounds.size.x / 32.0))
			var sy: int = maxi(1, int(bounds.size.y / 24.0))
			for y: int in range(bounds.position.y, bounds.end.y, sy):
				for x: int in range(bounds.position.x, bounds.end.x, sx):
					var color: Color = image.get_pixel(x, y)
					unique[Vector3i(int(color.r * 15.0), int(color.g * 15.0), int(color.b * 15.0))] = true
		checks.ok(unique.size() >= min_world_colors, "settled city capture contains varied rendered pixels (%d distinct color bins)" % unique.size())
	var path: String = OUT.path_join(name + ".png")
	checks.eq(image.save_png(path), OK, "capture written: " + name)
	captures.append(name + ".png")
	print("Stage G campaign capture: " + path)


func _wait_for_city_ready(reason: String) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 90000:
		await get_tree().process_frame
		var screen: Variant = app.screen
		if screen == null or screen.view != GameScreen.COLONY or Settings.appearance != "3d":
			continue
		var host: WorldViewportHost = screen.world_controller.host
		var city: Variant = host.renderer
		if not city is ColonyRenderer or not host.visible or bool(city.get("busy")):
			continue
		var landscape: Variant = city.get("_landscape")
		var city_root: Variant = city.get("_city")
		var finish_meshes: Dictionary = city.get("_finish_meshes")
		var snapshot: Dictionary = city.get("snapshot")
		var metrics: Dictionary = city.call("metrics")
		if not is_instance_valid(landscape) or not is_instance_valid(city_root):
			continue
		if int(metrics.get("completed", 0)) <= 0 or finish_meshes.is_empty():
			continue
		if int(snapshot.get("city_kit_version", 0)) != 3:
			continue
		await RenderingServer.frame_post_draw
		checks.ok(true, "%s city uses settled current-finish geometry and is visible" % reason)
		return true
	checks.fail("%s city renderer did not reach visible settled current-finish geometry within 90 seconds" % reason)
	return false


func _counts(state: GameState) -> Dictionary:
	var e: Empire = state.player()
	var outposts: int = 0
	var settled: int = 0
	var buildings: int = 0
	var districts: int = 0
	var upgrades: int = 0
	for colony: Colony in state.colonies_of(state.player_id):
		if colony.is_outpost():
			outposts += 1
		else:
			settled += 1
			buildings += colony.buildings.size()
			districts += colony.districts.size()
			for placed: Colony.PlacedDistrict in colony.districts:
				if placed.tier > 1:
					upgrades += 1
	return {
		"turn": state.turn,
		"techs": e.techs.size(),
		"events": state.event_log.size(),
		"surveyed_planets": e.surveyed_planets.size(),
		"settled_colonies": settled,
		"outposts": outposts,
		"buildings": buildings,
		"districts": districts,
		"upgraded_districts": upgrades,
		"outcome": state.outcome,
		"state_hash": state.state_hash(),
	}


func _show_game_view(view: String) -> void:
	var gs: Variant = app.screen
	if gs == null:
		return
	match view:
		"research":
			gs.show_view("research")
		"survey":
			gs.show_view("galaxy")
			gs.system_id = "sys_ember"
			gs.show_view("system")
			var state: GameState = game.call("view")
			for pid: String in state.systems[gs.system_id].planet_ids:
				if not state.player().surveyed_planets.has(pid):
					gs.select_planet(pid)
					break
		"colony":
			var owned: Array[Colony] = (game.call("view") as GameState).colonies_of((game.call("view") as GameState).player_id)
			if not owned.is_empty():
				gs.open_colony(owned[0].id)
		"galaxy":
			gs.show_view("galaxy")
	await _frames(5)


func _process_decision(decision: BotPolicy.Decision, state_before: GameState) -> void:
	for command: Command in decision.commands:
		if command is ChooseEventCommand:
			var event_command: ChooseEventCommand = command as ChooseEventCommand
			var gs: Variant = app.screen
			var live_view: GameState = game.call("view")
			var pending: Array[EventInstance] = Events.pending_for(live_view, state_before.player_id)
			checks.ok(not pending.is_empty(), "event order has a live pending event")
			if not pending.is_empty():
				checks.eq(event_command.event_id, pending[0].id, "event overlay matches the real pending event")
			var event_script: GDScript = load("res://ui/screens/game/event_overlay.gd") as GDScript
			var modal: Node = event_script.call("open", gs, event_command.event_id, Callable()) as Node
			await _frames(4)
			if not bool(milestones.get("event_shown", false)):
				await _capture("04_live_event", false)
				milestones["event_shown"] = true
			var choice_name: String = "Choice_%d" % event_command.choice
			await _click(choice_name, modal)
			command_counts["choose_event"] = int(command_counts.get("choose_event", 0)) + 1
		else:
			var result: Result = game.call("submit", command)
			checks.ok(result.ok, "valid balanced-bot order queued: " + command.type_id() + " " + str(command.to_dict()))
			if result.ok:
				command_counts[command.type_id()] = int(command_counts.get(command.type_id(), 0)) + 1
				if command is PickResearchCommand and not bool(milestones.get("research_view", false)):
					await _show_game_view("research")
					await _capture("03_research_and_unlocks")
					milestones["research_view"] = true
				elif command is SurveyCommand and not bool(milestones.get("survey_order", false)):
					await _show_game_view("survey")
					await _capture("05_survey_command")
					milestones["survey_order"] = true
				elif command is ColoniseCommand and not bool(milestones.get("founding_order", false)):
					await _show_game_view("survey")
					await _capture("06_founding_command")
					milestones["founding_order"] = true
				elif command is BuildOutpostCommand and not bool(milestones.get("outpost_order", false)):
					await _show_game_view("survey")
					await _capture("07_outpost_command")
					milestones["outpost_order"] = true
				elif command is BuildBuildingCommand or command is PlaceDistrictCommand:
					if not bool(milestones.get("construction_order", false)):
						await _show_game_view("colony")
						await _capture("08_construction_queue")
						milestones["construction_order"] = true
				elif command is UpgradeDistrictCommand and not bool(milestones.get("upgrade_order", false)):
					await _show_game_view("colony")
					await _capture("09_upgrade_queue")
					milestones["upgrade_order"] = true
	await _frames(2)


func _save_load(state_before: GameState) -> void:
	var services: Node = root.get_node("SaveService")
	services.set("dir", "user://m11_stage_g_campaign_seed1")
	var before_fields: Dictionary = root.get_node("Worlds").call("save_fields", state_before)
	save_slot = services.call("save_manual", state_before)
	checks.not_ok(save_slot.is_empty(), "manual save wrote through production SaveService")
	if save_slot.is_empty():
		return
	var saved_hash: String = state_before.state_hash()
	var saved_turn: int = state_before.turn
	var saved_load: SaveSerializer.LoadResult = services.call("load_slot", save_slot)
	checks.ok(saved_load.ok, "manual save parses through production LoadScreen serializer")
	checks.eq(saved_load.state.state_hash(), saved_hash, "serializer preserves simulation state before UI load")
	app.call("go", "load", {"back": "game"})
	await _frames(5)
	await _click("Load", app.screen.find_child("Save_" + save_slot, true, false))
	await _frames(6)
	checks.eq(app.route, "game", "Load screen returns to the running game")
	checks.eq(game.get("state").turn, saved_turn, "loaded save restores current campaign turn")
	checks.eq(game.get("state").state_hash(), saved_hash, "loaded save restores exact simulation state")
	var after_fields: Dictionary = root.get_node("Worlds").call("save_fields", game.get("state"))
	checks.eq(after_fields.get("presentation", ""), before_fields.get("presentation", ""), "load preserves the save's graphics appearance envelope")
	checks.eq(after_fields.get("presentation_overlay", ""), before_fields.get("presentation_overlay", ""), "load preserves the campaign's staged visual changes")
	checks.eq(after_fields, before_fields, "load preserves graphics anchors, staged clearings and all presentation fields")
	var envelope: Dictionary = PresentationEnvelope.inspect(str(after_fields.get("presentation", "")))
	checks.eq(envelope.get("status", ""), "supported", "loaded graphics envelope remains readable")
	checks.eq(envelope.get("data", {}).get("catalog", {}).get("city_kit", 0), 3, "campaign uses current city catalog after load")
	milestones["save_load"] = {"slot": save_slot, "turn": saved_turn, "hash": saved_hash}
	await _wait_for_city_ready("post-load")
	await _capture("10_save_loaded", true, 20)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("m11_stage_g_campaign needs a display; run under xvfb-run")
		get_tree().quit(2)
		return
	root.size = Vector2i(1920, 1080)
	root.get_node("Layout").call("set_profile", 1)
	var settings: Node = root.get_node("Settings")
	settings.set("persist", false)
	settings.call("set_hints_enabled", false)
	settings.call("set_appearance", "strategic")
	settings.call("set_view_mode", "command")
	settings.call("set_visual_quality", "standard")
	error_catcher = ErrorCatcher.new()
	OS.add_logger(error_catcher)
	DirAccess.make_dir_recursive_absolute(OUT)
	var ignore: FileAccess = FileAccess.open(OUT.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	app = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	root.get_node("SaveService").set("dir", "user://m11_stage_g_campaign_seed1")
	root.add_child(app)
	game = root.get_node("Game")
	await _frames(5)
	await _capture("01_title")
	await _click("Campaign")
	checks.eq(app.route, "campaign", "title opens campaign through its real control")
	await _capture("02_campaign")
	await _click("Play", app.screen.find_child("Scenario_" + SCENARIO, true, false))
	checks.eq(app.route, "briefing", "campaign opens First Light briefing through its real control")
	await _capture("02b_briefing")
	# AppRoot's seeded BEGIN action is used to make this playable campaign reproducible.
	app.call("go", "begin", {"scenario": SCENARIO, "seed": GAME_SEED})
	await _frames(8)
	root.get_node("Overlay").call("close_all")
	checks.eq(game.get("state").game_seed, GAME_SEED, "fresh First Light starts from the pinned campaign seed")
	checks.eq(game.get("state").scenario_id, SCENARIO, "live game uses canonical First Light data")
	opening_counts = _counts(game.get("state"))
	await _capture("02c_first_light_opening")
	var expected: BotRunner.Run = BotRunner.run(Content.db(), SCENARIO, "balanced", GAME_SEED, MAX_TURNS, "normal")
	expected_hashes = expected.hashes.duplicate()
	checks.eq(expected.outcome, GameState.OUTCOME_WON, "pinned campaign path legitimately reaches the win state")
	for step in MAX_TURNS:
		if game.get("state").is_over():
			break
		if step % 10 == 0:
			print("Stage G campaign progress: completed %d / %d turns" % [step, MAX_TURNS])
		var state: GameState = game.get("state")
		var decision: BotPolicy.Decision = BotPolicy.decide("balanced", state, state.player_id, state.game_seed)
		await _process_decision(decision, state)
		var turn: TurnResult = game.call("end_turn")
		var live_state: GameState = game.get("state")
		if step + 1 >= expected_hashes.size():
			checks.fail("live campaign continued after BotRunner terminal turn %d; actual turn %d, outcome %s, hash %s" % [expected_hashes.size() - 1, live_state.turn, live_state.outcome, live_state.state_hash()])
			break
		var expected_hash: String = expected_hashes[step + 1]
		if live_state.state_hash() != expected_hash:
			checks.fail("live command-bus replay diverged at turn %d: expected %s, got %s; %d balanced orders this turn" % [live_state.turn, expected_hash, live_state.state_hash(), decision.commands.size()])
			break
		checks.ok(true, "live Game command bus hash matches pinned BotRunner replay at turn %d" % live_state.turn)
		var counts: Dictionary = _counts(live_state)
		if int(counts["techs"]) > 0 and not milestones.has("research_unlocked"):
			milestones["research_unlocked"] = counts["turn"]
		if int(counts["surveyed_planets"]) > int(opening_counts["surveyed_planets"]) and not milestones.has("survey_completed"):
			milestones["survey_completed"] = counts["turn"]
		if int(counts["settled_colonies"]) > int(opening_counts["settled_colonies"]) and not milestones.has("colony_founded"):
			milestones["colony_founded"] = counts["turn"]
		if int(counts["outposts"]) > int(opening_counts["outposts"]) and not milestones.has("outpost_completed"):
			milestones["outpost_completed"] = counts["turn"]
		if int(counts["buildings"]) + int(counts["districts"]) > int(opening_counts["buildings"]) + int(opening_counts["districts"]) and not milestones.has("construction_completed"):
			milestones["construction_completed"] = counts["turn"]
		if int(counts["upgraded_districts"]) > int(opening_counts["upgraded_districts"]) and not milestones.has("upgrade_completed"):
			milestones["upgrade_completed"] = counts["turn"]
		if live_state.turn == 15:
			await _show_game_view("galaxy")
			await _capture("campaign_turn_15_command_strategic")
		if live_state.turn == 35:
			settings.call("set_appearance", "3d")
			settings.call("set_view_mode", "command")
			await _show_game_view("colony")
			var city_hash: String = live_state.state_hash()
			await _wait_for_city_ready("Command layout")
			var city_host: WorldViewportHost = app.screen.world_controller.host
			var city_renderer: Variant = city_host.renderer
			var city_id: int = city_renderer.get_instance_id() if city_renderer is Object else 0
			var city_camera: Dictionary = city_renderer.call("camera_state") if city_renderer is Object else {}
			checks.ok(city_id > 0, "settled colony renderer has a stable instance")
			checks.not_ok(app.screen.call("immersive_active"), "3D Colony remains in Command layout before toggle")
			await _capture("campaign_turn_35_3d_command", true, 20)
			await _toggle_layout("immersive")
			checks.ok(app.screen.call("immersive_active"), "3D Colony enters Immersive rendering after real layout toggle")
			await _frames(10)
			await _capture("campaign_turn_35_3d_immersive", true, 20)
			await _toggle_layout("command")
			checks.eq(game.get("state").state_hash(), city_hash, "city layout changes preserve the committed simulation hash")
			checks.eq(city_host.renderer.get_instance_id(), city_id, "Command and Immersive retain the same settled city renderer")
			checks.eq(city_host.renderer.call("camera_state"), city_camera, "Command and Immersive retain the same settled city camera")
		if live_state.turn == 55 and not milestones.has("save_load"):
			await _wait_for_city_ready("pre-save")
			await _save_load(live_state)
		if live_state.is_over():
			break
		if turn.state.is_over():
			break
	checks.eq(game.get("state").outcome, GameState.OUTCOME_WON, "campaign reaches the production victory state")
	app.call("go", "debrief")
	await _frames(8)
	checks.eq(app.route, "debrief", "won campaign opens production debrief")
	checks.ok(app.screen.call("won"), "debrief shows the actual won GameState")
	await _capture("11_debrief_won")
	var required: Array[String] = ["research_view", "research_unlocked", "event_shown", "survey_order", "survey_completed", "founding_order", "colony_founded", "outpost_order", "outpost_completed", "construction_order", "construction_completed", "upgrade_order", "upgrade_completed", "save_load"]
	for key: String in required:
		checks.ok(milestones.has(key), "campaign milestone observed: " + key)
	for key: String in ["pick_research", "choose_event", "survey", "colonise", "build_outpost", "build_building", "place_district", "upgrade_district"]:
		checks.ok(int(command_counts.get(key, 0)) > 0, "campaign used real command type: " + key)
	for error: String in error_catcher.call("take"):
		checks.fail(error)
	OS.remove_logger(error_catcher)
	root.get_node("SaveService").set("dir", "user://saves")
	var report: Dictionary = {
		"qualification": "Production AppRoot screens and Game command bus; deterministic balanced policy plays canonical First Light scenario at normal difficulty, seed 1. No injected resources, technologies, units, colonies or event choices. Every live turn hash is compared to BotRunner's same seed replay, including the policy's legal Advanced Districts upgrade. Command and Immersive captures use the same settled, current-finish city geometry.",
		"checks": checks.checks, "failures": checks.failures, "seed": GAME_SEED,
		"outcome": game.get("state").outcome, "outcome_turn": game.get("state").outcome_turn,
		"final_state_hash": game.get("state").state_hash(), "expected_final_state_hash": expected.hashes.back(),
		"opening_counts": opening_counts, "milestones": milestones, "command_counts": command_counts,
		"captures": captures, "simulation_hashes_checked": expected_hashes.size(),
	}
	var output: FileAccess = FileAccess.open(OUT.path_join("verification.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("M1.1 STAGE G CAMPAIGN: %d checks, %d failures, won at turn %d" % [checks.checks, checks.failures.size(), game.get("state").outcome_turn])
	for failure: String in checks.failures:
		printerr(failure)
	get_tree().quit(0 if checks.failures.is_empty() else 1)
