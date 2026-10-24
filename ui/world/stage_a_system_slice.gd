class_name M11StageASystemSlice
extends VBoxContainer
## An opt-in integrated System slice for Stage A export/latency feasibility.
## Production lifecycle/controller ownership is implemented in Stage B.

var screen: GameScreen
var renderer: M1SystemRenderer
var inspector: VBoxContainer
var first_draw_us: int = 0
var started_us: int = 0

static func make(owner_screen: GameScreen) -> M11StageASystemSlice:
	var slice: M11StageASystemSlice = M11StageASystemSlice.new()
	slice.screen = owner_screen
	slice.name = "SpatialSystem"
	return slice

func _ready() -> void:
	started_us = Time.get_ticks_usec()
	add_theme_constant_override("separation",Tokens.SPACE_M)
	var system: StarSystem = screen.state.systems[screen.system_id]
	var head: Card = Card.make(Strings.fmt(system.name_key),Strings.fmt(SystemView.STAR_KEYS.get(system.spectral,"ui.worlds.star.g")),"emblem_hearth","hearth.gold")
	head.name = "SystemHeader"; add_child(head)
	var controls: HFlowContainer = HFlowContainer.new()
	controls.add_theme_constant_override("h_separation",Tokens.SPACE_S)
	head.add_body(controls)
	var overview: SfButton = SfButton.make("ui.3d.overview","emblem_compass",SfButton.GHOST)
	overview.name = "SystemOverview"
	overview.pressed.connect(func() -> void: renderer.show_overview())
	controls.add_child(overview)
	var split: BoxContainer = BoxContainer.new()
	split.vertical = Layout.compact
	split.add_theme_constant_override("separation",Tokens.SPACE_M)
	add_child(split)
	renderer = M1SystemRenderer.new()
	renderer.name = "SystemViewport"
	renderer.cooperative_bakes = true
	renderer.overview_width = 128
	renderer.focus_width = 512
	renderer.generation_slice_us = 1000
	renderer.render_scale_divisor = 2
	renderer.custom_minimum_size = Vector2(0,280 if Layout.compact else 440)
	renderer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renderer.configure(M1VisualSnapshot.system_view(screen.state,screen.system_id))
	renderer.selected.connect(_selected)
	split.add_child(renderer)
	inspector = GameUI.column(Tokens.SPACE_M)
	inspector.name = "SystemInspector"
	inspector.custom_minimum_size.x = 0 if Layout.compact else 320
	split.add_child(inspector)
	for planet_id: String in system.planet_ids:
		var planet: Planet = screen.state.planets[planet_id]
		var button: SfButton = SfButton.make("", "planet_"+planet.type,SfButton.GHOST)
		button.name = "Focus_"+planet_id
		button.text = Strings.fmt(planet.name_key)
		button.pressed.connect(func() -> void: renderer.focus_body(planet_id))
		controls.add_child(button)
	_refresh_inspector()
	if screen.state.planets.has(screen.planet_id): renderer.focus_body(screen.planet_id,false)
	_record_first_draw.call_deferred()

func _record_first_draw() -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree(): first_draw_us = Time.get_ticks_usec()-started_us

func _selected(id: String) -> void:
	if screen.state.planets.has(id): screen.planet_id = id
	else: screen.planet_id = ""
	_refresh_inspector()

func _refresh_inspector() -> void:
	for child: Node in inspector.get_children():
		inspector.remove_child(child); child.queue_free()
	if screen.state.planets.has(screen.planet_id):
		inspector.add_child(SystemView._panel(screen,screen.state.planets[screen.planet_id]))
	else:
		var hint: Card = Card.make(Strings.fmt("ui.system.pick_title"),"","map_outpost","text.secondary")
		hint.add_text(Strings.fmt("ui.system.pick_hint")); inspector.add_child(hint)
	inspector.add_child(SystemView._fleets(screen,screen.state.systems[screen.system_id]))

func metrics() -> Dictionary:
	return {"backend":"cooperative","first_draw_us":first_draw_us,
		"generation_us":Array(renderer.generation_samples),"upload_us":Array(renderer.upload_samples),
		"cache_texture_bytes_estimate":renderer.cache_texture_bytes_estimate(),
		"engine_static_bytes":OS.get_static_memory_usage(),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"focused_width":renderer.bodies.get(renderer.selected_id,{}).get("width",0)}
