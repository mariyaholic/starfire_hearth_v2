class_name M11StageCProbe
extends Node
## Explicit ?smoke=m11-stage-c test route; the ordinary entry never auto-plays.
var app: AppRoot
var phase: String = "starting"
var action: String = ""
var initial_hash: String = ""
var expected_hash: String = ""
var actual_hash: String = ""
var frame_ms: PackedFloat64Array = PackedFloat64Array()
var _elapsed: float = 0

func start(owner: AppRoot) -> void:
	app = owner
	for i: int in 2: await get_tree().process_frame
	Settings.persist = false; Settings.set_hints_enabled(false); Settings.set_reduce_motion(true)
	Settings.set_appearance("3d"); Settings.set_visual_quality("auto")
	app.go(AppRoot.BEGIN,{"scenario":"s1_first_light","seed":11})
	for i: int in 6: await get_tree().process_frame
	Overlay.close_all()
	var screen: GameScreen = app.screen
	screen.show_view(GameScreen.GALAXY)
	initial_hash = Game.view().state_hash()
	phase = "ready"
	_publish()

func _process(delta: float) -> void:
	if phase == "starting": return
	frame_ms.append(delta*1000)
	if frame_ms.size() > 512: frame_ms.remove_at(0)
	_elapsed += delta
	if _elapsed < 0.25: return
	_elapsed = 0
	if OS.has_feature("web"):
		action = str(JavaScriptBridge.eval("window.__m11StageCAction || ''",true))
		if not action.is_empty(): JavaScriptBridge.eval("window.__m11StageCAction = ''",true)
	if action == "resolve_survey":
		action = ""
		_resolve(2,"resolved")
	elif action == "prepare_command_fixture":
		action = ""
		# Explicit fixture, shared with the native tour. Gameplay commands below still
		# validate, pay and complete through M1; ordinary entry never runs this hook.
		var fixture: GameState = GameState.from_dict(Game.view().to_dict())
		fixture.player().stock["influence"] = 50000
		Ships.launch(fixture,fixture.colonies_of(fixture.player_id)[0],"colony_ship")
		Game.resume(fixture)
		phase = "fixture_ready"
	elif action in ["resolve_colonise","resolve_tithe_survey","resolve_outpost"]:
		var requested: String = action; action = ""
		_resolve({"resolve_colonise":1,"resolve_tithe_survey":2,"resolve_outpost":4}[requested],requested+"_done")
	_publish()

func _resolve(turns: int, next_phase: String) -> void:
	var reference: TurnResult = TurnProcessor.run(GameState.from_dict(Game.state.to_dict()), Game.queue.commands())
	for i: int in turns-1: reference = TurnProcessor.run(reference.state,[] as Array[Command])
	expected_hash = reference.state_hash
	for i: int in turns: Game.end_turn()
	actual_hash = Game.state.state_hash()
	phase = next_phase
	_close_overlays.call_deferred()

func _close_overlays() -> void:
	for i: int in 5: await get_tree().process_frame
	Overlay.close_all()

func _publish() -> void:
	var screen: GameScreen = app.screen as GameScreen
	if screen == null: return
	var renderer: Control = screen.world_controller.host.renderer
	var controls: Dictionary = {}
	for named: Node in screen.find_children("*","",true,false):
		var key: String = str(named.name)
		if not (key.begins_with("Focus_") or key.begins_with("Survey_") or key.begins_with("Colonise_") or key.begins_with("Outpost_") or key.begins_with("System_") or key in ["Nav_system","SystemOverview","AppearanceStrategic","Appearance3D","CameraReset"]): continue
		var button: BaseButton = named as BaseButton
		if button == null:
			for child: Node in named.find_children("*","BaseButton",true,false): button=child as BaseButton; break
		if button == null: continue
		var rect: Rect2 = button.get_global_rect()
		controls[key] = {"x":rect.get_center().x,"y":rect.get_center().y,"enabled":not button.disabled}
	var renderer_data: Dictionary = {}
	if renderer != null:
		var rect: Rect2 = renderer.get_global_rect()
		renderer_data = {"instance":renderer.get_instance_id(),"camera_yaw":renderer.get("_yaw"),"camera_distance":renderer.get("_distance"),
			"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y,
			"upload_us":Array(renderer.get("upload_samples")),"body_ids":renderer.get("bodies").keys(),"focused_width":0}
		if screen.view == GameScreen.SYSTEM and renderer.get("bodies").has(screen.planet_id):
			renderer_data["focused_width"] = renderer.get("bodies")[screen.planet_id]["width"]
	var telemetry: Dictionary = {"phase":phase,"web":OS.has_feature("web"),"view":screen.view,"appearance":Settings.appearance,
		"controls":controls,"viewport":{"x":get_viewport().get_visible_rect().size.x,"y":get_viewport().get_visible_rect().size.y},
		"scrollbar":{"x":screen._scroll.get_v_scroll_bar().get_global_rect().get_center().x,"y":screen._scroll.get_v_scroll_bar().get_global_rect().get_center().y},
		"clip":{"top":screen._scroll.get_global_rect().position.y,"bottom":screen._scroll.get_global_rect().end.y},
		"initial_hash":initial_hash,"preview_hash":Game.view().state_hash(),"expected_hash":expected_hash,"actual_hash":actual_hash,
		"turn":Game.state.turn,"planet":screen.planet_id,"surveyed":Game.view().player().surveyed_planets.has("pl_brume"),
		"brume_colony":Game.view().planets["pl_brume"].colony_id,"tithe_outpost":Game.view().planets["pl_tithe"].colony_id,
		"renderer":renderer_data,"scene_visible":screen.world_controller.host.visible,"scheduler":Worlds.scheduler.metrics(),"cache":Worlds.cache.metrics(),"frames_ms":Array(frame_ms)}
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__m11StageC = " + JSON.stringify(telemetry),true)
