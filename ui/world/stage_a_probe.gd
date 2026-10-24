class_name M11StageAProbe
extends Node
## Exported test hook, enabled only by ?smoke=m11-stage-a. No automatic player actions.
var app: AppRoot
var phase: String = "starting"
var action: String = ""
var telemetry: Dictionary = {}
var initial_hash: String = ""
var expected_hash: String = ""
var actual_hash: String = ""
var baseline_static_bytes: int = 0
var frame_ms: PackedFloat64Array = PackedFloat64Array()
var _elapsed: float = 0.0

func start(owner_app: AppRoot) -> void:
	app = owner_app
	# Let the title's existing deferred focus finish before changing the route.
	for i in 2: await get_tree().process_frame
	Settings.persist = false
	Settings.set_reduce_motion(true)
	Settings.set_hints_enabled(false)
	app.go(AppRoot.BEGIN,{"scenario":"s1_first_light","seed":11})
	for i in 6: await get_tree().process_frame
	Overlay.close_all()
	for i in 4: await get_tree().process_frame
	baseline_static_bytes = OS.get_static_memory_usage()
	var game_screen: GameScreen = app.screen as GameScreen
	game_screen.spatial_slice_enabled = true
	game_screen.show_view(GameScreen.SYSTEM)
	for i in 4: await get_tree().process_frame
	initial_hash = Game.view().state_hash()
	phase = "ready"
	_publish()

func _process(delta: float) -> void:
	if phase == "starting": return
	frame_ms.append(delta*1000)
	if frame_ms.size()>1024: frame_ms.remove_at(0)
	_elapsed += delta
	if _elapsed<0.25: return
	_elapsed=0
	if OS.has_feature("web"):
		action = str(JavaScriptBridge.eval("window.__m11StageAAction || ''",true))
		if not action.is_empty(): JavaScriptBridge.eval("window.__m11StageAAction = ''",true)
	if action == "resolve_survey":
		action = ""
		var reference: TurnResult = TurnProcessor.run(GameState.from_dict(Game.state.to_dict()),Game.queue.commands())
		reference = TurnProcessor.run(reference.state,[] as Array[Command])
		expected_hash = reference.state_hash
		Game.end_turn(); Game.end_turn()
		actual_hash = Game.state.state_hash()
		phase = "resolved"
		frame_ms.clear()
		_deferred_close.call_deferred()
	_publish()

func _deferred_close() -> void:
	for i in 5: await get_tree().process_frame
	Overlay.close_all()

func _publish() -> void:
	var gs: GameScreen = app.screen as GameScreen
	if gs == null: return
	var slice: M11StageASystemSlice = gs.find_child("SpatialSystem",true,false) as M11StageASystemSlice
	if slice == null: return
	var controls: Dictionary = {}
	for named: Node in gs.find_children("*","",true,false):
		if named.name.begins_with("Focus_") or named.name.begins_with("Survey_") or named.name=="SystemOverview":
			var button: BaseButton = named as BaseButton
			if button == null:
				var candidates: Array[Node] = named.find_children("*","BaseButton",true,false)
				if candidates.is_empty(): continue
				button = candidates[0] as BaseButton
			var rect: Rect2 = button.get_global_rect()
			controls[str(named.name)]={"x":rect.get_center().x,"y":rect.get_center().y,"enabled":not button.disabled}
	telemetry={"phase":phase,"web":OS.has_feature("web"),"backend":"cooperative",
		"scrollbar":{"x":gs._scroll.get_v_scroll_bar().get_global_rect().get_center().x,"y":gs._scroll.get_v_scroll_bar().get_global_rect().get_center().y},
		"clip":{"top":gs._scroll.get_global_rect().position.y,"bottom":gs._scroll.get_global_rect().end.y},
		"controls":controls,"viewport":{ "x":get_viewport().get_visible_rect().size.x,"y":get_viewport().get_visible_rect().size.y},
		"initial_hash":initial_hash,"preview_hash":Game.view().state_hash(),
		"expected_hash":expected_hash,"actual_hash":actual_hash,"planet":gs.planet_id,
		"turn":Game.state.turn,"surveyed":Game.view().player().surveyed_planets.has("pl_brume"),
		"baseline_static_bytes":baseline_static_bytes,"frames_ms":Array(frame_ms),"metrics":slice.metrics(),
		"worker_jobs":slice.renderer._jobs.size(),"cooperative_active":slice.renderer._incremental_job!=null}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__m11StageA = "+JSON.stringify(telemetry),true)
