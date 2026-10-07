class_name M1VisualStudy
extends OverlayLayer
## A concrete incorporation study inside M1. Its inspector uses M1's existing commands,
## costs, validation, explanations and queue controls. Its renderer receives detached data.

var screen: GameScreen
var mode: String = ""
var renderer: Control
var _content: VBoxContainer
var _inspector: VBoxContainer
var _split: BoxContainer
var _side_scroll: ScrollContainer
var _body_scroll: ScrollContainer
var _status: Label
var _pause: CheckButton
var _header: HBoxContainer
var _display_name: String = ""
var _refresh_pending: bool = false


static func make(game_screen: GameScreen, view_mode: String) -> M1VisualStudy:
	var study: M1VisualStudy = M1VisualStudy.new()
	study.name = "M1VisualStudy"
	study.screen = game_screen
	study.mode = view_mode
	return study


func _ready() -> void:
	panel = PanelContainer.new(); panel.theme_type_variation = &"Card"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_content = GameUI.column(Tokens.SPACE_M); panel.add_child(_content)
	_header = _make_header("",&"H2Label")
	_content.add_child(GameUI.exempt(_header,"3D names a presentation mode, not a game quantity"))
	var tools: HFlowContainer = HFlowContainer.new()
	tools.add_theme_constant_override("h_separation",Tokens.SPACE_M)
	_content.add_child(tools)
	var overview: SfButton = SfButton.make("ui.3d.overview","emblem_compass",SfButton.GHOST)
	overview.name = "3DOverview"; overview.pressed.connect(func() -> void: renderer.call("show_overview"))
	tools.add_child(overview)
	_pause = CheckButton.new(); _pause.text = Strings.fmt("ui.3d.pause"); _pause.button_pressed = Settings.reduce_motion
	_pause.toggled.connect(func(value: bool) -> void: renderer.set("motion_paused",value))
	tools.add_child(_pause)
	if mode == "colony":
		var planning_button: CheckButton = CheckButton.new(); planning_button.text = Strings.fmt("ui.3d.planning")
		planning_button.name = "3DPlanning"
		planning_button.toggled.connect(func(value: bool) -> void: renderer.call("_set_planning",value))
		tools.add_child(planning_button)
		var dusk_button: CheckButton = CheckButton.new(); dusk_button.text = Strings.fmt("ui.3d.dusk")
		dusk_button.name = "3DDusk"
		dusk_button.toggled.connect(func(value: bool) -> void: renderer.set("dusk",value); renderer.call("_apply_lighting"))
		tools.add_child(dusk_button)
	_split = BoxContainer.new(); _split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation",Tokens.SPACE_M)
	_body_scroll = OverlayLayer.make_scroll(_split)
	_content.add_child(_body_scroll)
	renderer = M1ColonyRenderer.new() if mode == "colony" else M1SystemRenderer.new()
	if mode == "colony":
		(renderer as M1ColonyRenderer).bind_generation(Worlds.scheduler,Worlds.session.epoch,"study:"+str(get_instance_id()))
	renderer.name = "3DViewport"; renderer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; renderer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(renderer)
	renderer.set("motion_paused",Settings.reduce_motion)
	_inspector = GameUI.column(Tokens.SPACE_M)
	_side_scroll = OverlayLayer.make_scroll(_inspector); _split.add_child(_side_scroll)
	_status = FlowScreen.label(Strings.fmt("ui.3d.controls"),&"CaptionLabel")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _content.add_child(_status)
	if mode == "colony": renderer.connect("selected",_select_slot)
	else: renderer.connect("selected",_select_body)
	Game.orders_changed.connect(_queue_refresh)
	Layout.changed.connect(_layout)
	_layout(); _refresh()


func _layout() -> void:
	if panel == null: return
	var margin: float = 8 if Layout.compact else 20
	panel.offset_left = margin; panel.offset_top = margin; panel.offset_right = -margin; panel.offset_bottom = -margin
	_split.vertical = Layout.compact
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if Layout.compact else ScrollContainer.SCROLL_MODE_DISABLED
	_split.size_flags_vertical = Control.SIZE_FILL if Layout.compact else Control.SIZE_EXPAND_FILL
	_side_scroll.custom_minimum_size = Vector2(0,210*Settings.text_scale) if Layout.compact else Vector2(minf(420*Settings.text_scale,size.x*0.36),0)
	_side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_FILL
	_side_scroll.size_flags_vertical = Control.SIZE_FILL if Layout.compact else Control.SIZE_EXPAND_FILL
	renderer.custom_minimum_size = Vector2(0,180 if Layout.compact else 280)
	_pause.text = Strings.fmt("ui.3d.pause_short" if Layout.compact else "ui.3d.pause")
	_pause.custom_minimum_size.y = Layout.target_size()
	for button: BaseButton in find_children("3D*","BaseButton",true,false): button.custom_minimum_size.y = Layout.target_size()
	var plan: CheckButton = find_child("3DPlanning",true,false) as CheckButton
	if plan != null: plan.text = Strings.fmt("ui.3d.plan_short" if Layout.compact else "ui.3d.planning")
	(_header.get_child(0) as Label).text = Strings.fmt("ui.3d.title_compact" if Layout.compact else ("ui.3d.city_title" if mode == "colony" else "ui.3d.system_title"),{"name":_display_name})


func _queue_refresh() -> void:
	if _refresh_pending: return
	_refresh_pending = true; _refresh.call_deferred()


func _refresh() -> void:
	_refresh_pending = false
	if not is_instance_valid(screen) or not Game.has_game(): close(); return
	screen.state = Game.view(); screen.report = Economy.empire(screen.state,screen.state.player_id)
	for child: Node in _inspector.get_children():
		_inspector.remove_child(child); child.queue_free()
	if mode == "colony":
		var snapshot: Dictionary = VisualSnapshotBuilder.build(screen.state,"colony",screen.colony_id,Worlds.session.epoch)
		if snapshot.is_empty(): close(); return
		if not snapshot["appearance_supported"]:
			Overlay.toast(Strings.fmt("ui.world.appearance_incompatible"),ReportItem.SEVERITY_WARNING)
			close(); return
		_display_name = snapshot["name"]
		var preview: Dictionary = {}
		if screen.slot >= 0 and not screen.pick.is_empty():
			var valid: Result
			if screen.pick_kind == "district":
				valid = PlaceDistrictCommand.create(screen.state.player_id,screen.colony_id,screen.slot,screen.pick,screen.branch_pick if screen.pick == "research" else "").validate(screen.state)
			else:
				valid = BuildBuildingCommand.create(screen.state.player_id,screen.colony_id,screen.slot,screen.pick).validate(screen.state)
			preview = {"slot":screen.slot,"kind":screen.pick_kind,"id":screen.pick,"tier":1,"valid":valid.ok}
		renderer.call("configure",snapshot,preview)
		var colony: Colony = screen.state.colonies[screen.colony_id]
		var report: Economy.ColonyReport = screen.report.colonies[colony.id]
		_inspector.add_child(ColonyView._slot_menu(screen,colony,report))
		_inspector.add_child(ColonyView._queue(screen,colony))
		_inspector.add_child(GameUI.caption(Strings.fmt("ui.3d.construction_note")))
		# The original picker rebuilds the game view; this study also needs its ghost refreshed.
		for option: BaseButton in _inspector.find_children("*","BaseButton",true,false):
			option.pressed.connect(_queue_refresh)
	else:
		var snapshot: Dictionary = VisualSnapshotBuilder.build(screen.state,"system",screen.system_id,Worlds.session.epoch)
		if snapshot.is_empty(): close(); return
		_display_name = Strings.fmt(snapshot["name_key"])
		renderer.call("configure",snapshot)
		var selectors: HFlowContainer = HFlowContainer.new()
		selectors.add_theme_constant_override("h_separation",Tokens.SPACE_S)
		selectors.add_theme_constant_override("v_separation",Tokens.SPACE_S)
		for planet: Dictionary in snapshot["planets"]:
			var button: SfButton = SfButton.make(planet["name_key"],"planet_continental",SfButton.GHOST)
			button.name = "3DPick_"+planet["id"]
			button.pressed.connect(func() -> void: renderer.call("focus_body",planet["id"]))
			selectors.add_child(button)
		_inspector.add_child(selectors)
		if not screen.planet_id.is_empty() and screen.state.planets.has(screen.planet_id):
			_inspector.add_child(SystemView._panel(screen,screen.state.planets[screen.planet_id]))
			var open_colony: BaseButton = _inspector.find_child("OpenColony",true,false) as BaseButton
			if open_colony != null: open_colony.pressed.connect(close)
		_inspector.add_child(SystemView._fleets(screen,screen.state.systems[screen.system_id]))
	_layout()


func _select_slot(index: int) -> void:
	screen.select_slot(index)
	_refresh()


func _select_body(id: String) -> void:
	if screen.state.planets.has(id):
		screen.select_planet(id)
		_refresh()


func _process(_delta: float) -> void:
	if renderer == null: return
	var preparing: bool = bool(renderer.get("busy")) if mode == "colony" else false
	_status.text = Strings.fmt("ui.3d.preparing" if preparing else ("ui.3d.compact_controls" if Layout.compact else "ui.3d.controls"))
	if not preparing and renderer.has_method("hover_text"):
		var hovered: String = renderer.call("hover_text")
		if not hovered.is_empty(): _status.text = Strings.fmt("ui.3d.hover",{"name":hovered})
	_pause.set_pressed_no_signal(bool(renderer.get("motion_paused")) or Settings.reduce_motion)
