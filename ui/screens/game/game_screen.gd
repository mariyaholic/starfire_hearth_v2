class_name GameScreen
extends Control
## The game screen (§7 screens 3–10): the top bar over the current view, a navigation rail on PC or
## a tab bar on phones, the advisor's tutorial card, and End Turn with its checklist. Views
## (`*_view.gd`) are built from Game.view(), the state as this turn's orders leave it, and rebuilt
## whenever the orders change; they give orders through `order()`, which says why when one is
## refused. After End Turn the screen shows the report, then each pending event, then the debrief
## when the game is over (the app has already auto-saved).

signal navigate(route: String, args: Dictionary)

const GALAXY: String = "galaxy"
const SYSTEM: String = "system"
const COLONY: String = "colony"
const RESEARCH: String = "research"
const ORDINANCES: String = "ordinances"
const MARKET: String = "market"
const OBJECTIVES: String = "objectives"

## View id, name key, icon.
const NAV: Array[Array] = [
	[GALAXY, "ui.nav.galaxy", "emblem_compass"],
	[SYSTEM, "ui.nav.system", "emblem_hearth"],
	[COLONY, "ui.nav.colony", "ui_colony"],
	[RESEARCH, "ui.nav.research", "ui_tree"],
	[ORDINANCES, "ui.nav.ordinances", "ui_edict"],
	[MARKET, "ui.nav.market", "bld_market_exchange"],
	[OBJECTIVES, "ui.nav.objectives", "ui_objective"],
]
## On phones these sit in the tab bar; the other views are behind "More".
const TABS_COMPACT: Array[String] = [SYSTEM, COLONY, RESEARCH]
## The advisor's highlight names (scenario data) and the control each one points at.
const HIGHLIGHTS: Dictionary[String, String] = {
	"topbar.food": "Chip_Food", "nav.research": "Nav_research", "nav.system": "Nav_system",
	"nav.ordinances": "Nav_ordinances", "nav.objectives": "Nav_objectives",
	"colony.planner": "PlannerGrid", "colony.stability": "Stat_stability",
	"colony.shipyard": "Shipyard", "colony.governor": "GovernorCard",
}
## The view a highlight is about, for the advisor's "Show me".
const HIGHLIGHT_VIEWS: Dictionary[String, String] = {
	"nav.research": RESEARCH, "nav.system": SYSTEM, "nav.ordinances": ORDINANCES,
	"nav.objectives": OBJECTIVES, "colony.planner": COLONY, "colony.stability": COLONY,
	"colony.shipyard": COLONY, "colony.governor": COLONY,
}
const MAX_WIDTH: float = 1320.0

## What the screen is showing.
var view: String = COLONY
var system_id: String = ""
var planet_id: String = ""
var colony_id: String = ""
## The planner's chosen slot (-1 for none), and what it is previewing there.
var slot: int = -1
var pick_kind: String = "district"
var pick: String = ""
var branch_pick: String = "physics"
## Opt-in feasibility slice; production view selection/settings follow in Stage B/C.
var spatial_slice_enabled: bool = false
var world_controller: WorldViewController
## The state as this turn's orders leave it, and its economy.
var state: GameState = null
var report: Economy.EmpireReport = null

static var _opened_seed: int = -1

var _bg: ColorRect
var _root: VBoxContainer
var _top: TopBar
var _nav_inner: Container
var _scroll: ScrollContainer
var _advisor_box: VBoxContainer
var _view_box: VBoxContainer
var _ring: HighlightRing
var _refresh_queued: bool = false
var _relayout_queued: bool = false
var _step: Dictionary = {}
var _immersive_layout: bool = false
var immersive_panel: String = "inspect"
var immersive_panel_open: bool = false


func _ready() -> void:
	name = "GameScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Game.has_game():
		go.call_deferred(AppRoot.TITLE)
		return
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = Tokens.color("bg.deep")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_ring = HighlightRing.new()
	add_child(_ring)
	world_controller = WorldViewController.new()
	add_child(world_controller)
	world_controller.setup(self)
	world_controller.selection_requested.connect(_world_selected)
	Settings.changed.connect(_world_setting_changed)
	state = Game.view()
	var cap: Colony = GameModel.capital(state)
	if cap != null:
		colony_id = cap.id
		system_id = state.planets[cap.planet_id].system_id
	Game.orders_changed.connect(_queue_refresh)
	Game.session_started.connect(_world_new_session)
	Layout.changed.connect(_queue_relayout)
	_build_layout()
	_refresh()
	_start.call_deferred()


func go(route: String, args: Dictionary = {}) -> void:
	navigate.emit(route, args)


# --- Layout ------------------------------------------------------------------------------------

func _build_layout() -> void:
	if _root != null:
		remove_child(_root)
		_root.queue_free()
	var m: Vector4 = Layout.safe_margins
	_root = VBoxContainer.new()
	_root.name = "Root"
	_root.add_theme_constant_override("separation", 0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	move_child(_root, 1)
	_top = TopBar.new()
	_immersive_layout = immersive_active()
	_top.compact_summary = _immersive_layout and Layout.compact
	_top.menu_pressed.connect(open_menu)
	_root.add_child(_top)
	if _immersive_layout:
		_build_immersive_layout()
		return
	# Command mounts occupy only their own card; the host sits above that placeholder.
	move_child(world_controller.host, get_child_count()-1)
	var mid: BoxContainer
	if Layout.compact:
		mid = VBoxContainer.new()
	else:
		mid = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	_root.add_child(mid)
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "NavBar"
	bar.theme_type_variation = &"BarPanel"
	var inset: MarginContainer = MarginContainer.new()
	bar.add_child(inset)
	if Layout.compact:
		inset.add_theme_constant_override("margin_left", int(m.x))
		inset.add_theme_constant_override("margin_right", int(m.z))
		inset.add_theme_constant_override("margin_bottom", int(m.w))
		_nav_inner = HBoxContainer.new()
	else:
		inset.add_theme_constant_override("margin_left", int(m.x))
		inset.add_theme_constant_override("margin_bottom", int(m.w))
		_nav_inner = VBoxContainer.new()
		_nav_inner.custom_minimum_size.x = 176.0 * Settings.text_scale
	_nav_inner.add_theme_constant_override("separation", Tokens.SPACE_S)
	inset.add_child(_nav_inner)
	var host: MarginContainer = MarginContainer.new()
	host.name = "ViewHost"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad: int = Tokens.SPACE_M if Layout.compact else Tokens.SPACE_XL
	var rail_w: float = 0.0 if Layout.compact else 176.0 * Settings.text_scale + m.x + 2.0 * Tokens.SPACE_M
	var room: float = Layout.logical_size.x - m.z - (0.0 if not Layout.compact else m.x) - rail_w - 2 * pad
	var extra: int = maxi(0, int((room - MAX_WIDTH) / 2.0))
	host.add_theme_constant_override("margin_left", pad + extra)
	host.add_theme_constant_override("margin_right", pad + extra + int(m.z))
	host.add_theme_constant_override("margin_top", pad)
	host.add_theme_constant_override("margin_bottom", pad)
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	_advisor_box = GameUI.column()
	_advisor_box.name = "Advisor"
	col.add_child(_advisor_box)
	_view_box = GameUI.column()
	_view_box.name = "View"
	col.add_child(_view_box)
	_scroll = FlowScreen.scroll_of(col)
	host.add_child(_scroll)
	if Layout.compact:
		mid.add_child(host)
		mid.add_child(bar)
	else:
		mid.add_child(bar)
		mid.add_child(host)


func immersive_active() -> bool:
	if Settings.view_mode != "immersive" or Settings.appearance != "3d" or spatial_slice_enabled:
		return false
	if view in [SYSTEM, GALAXY]: return true
	if view != COLONY or state == null: return false
	var colony: Colony = state.colonies.get(colony_id,null)
	return colony != null and not colony.is_outpost()


func _build_immersive_layout() -> void:
	# Transparent layout containers let the persistent viewport receive input beneath
	# the HUD. Context panels are above it and stop pointer/touch input locally.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(world_controller.host, 1)
	move_child(_root, 2)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advisor_box = GameUI.column()
	_advisor_box.name = "Advisor"
	_advisor_box.visible = false
	col.add_child(_advisor_box)
	_view_box = GameUI.column(0)
	_view_box.name = "View"
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_view_box)
	_scroll = FlowScreen.scroll_of(col)
	_scroll.name = "ImmersiveCanvas"
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "ImmersiveToolbar"
	bar.theme_type_variation = &"BarPanel"
	_root.add_child(bar)
	if Layout.compact:
		var stylebox: StyleBox = bar.get_theme_stylebox("panel").duplicate()
		for side: int in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: stylebox.set_content_margin(side,0)
		bar.add_theme_stylebox_override("panel",stylebox)
	var inset: MarginContainer = MarginContainer.new()
	var m: Vector4 = Layout.safe_margins
	inset.add_theme_constant_override("margin_left",int(m.x))
	inset.add_theme_constant_override("margin_right",int(m.z))
	inset.add_theme_constant_override("margin_bottom",int(m.w))
	bar.add_child(inset)
	_nav_inner = HFlowContainer.new()
	_nav_inner.add_theme_constant_override("h_separation",0 if Layout.compact else Tokens.SPACE_XS)
	_nav_inner.add_theme_constant_override("v_separation",Tokens.SPACE_XS)
	inset.add_child(_nav_inner)


func toggle_view_mode() -> void:
	Settings.set_view_mode("command" if Settings.view_mode == "immersive" else "immersive")


func toggle_immersive_panel(kind: String) -> void:
	var layout: Dictionary=ImmersiveWorkspace.load_layout(view,Layout.compact)
	ImmersiveWorkspace.toggle(layout,kind)
	ImmersiveWorkspace.save_layout(view,Layout.compact,layout)
	_refresh_view()
	_refresh_nav()


func close_immersive_panel() -> void:
	var layout: Dictionary=ImmersiveWorkspace.load_layout(view,Layout.compact)
	layout["open"].erase(layout["active"])
	layout["active"]="" if layout["open"].is_empty() else layout["open"][-1]
	ImmersiveWorkspace.save_layout(view,Layout.compact,layout)
	_refresh_view()
	_refresh_nav()

func reset_immersive_workspace() -> void:
	ImmersiveWorkspace.save_layout(view,Layout.compact,ImmersiveWorkspace.defaults(view))
	_refresh_view(); _refresh_nav()

func reveal_immersive_inspector() -> void:
	if not _immersive_layout: return
	var layout: Dictionary=ImmersiveWorkspace.load_layout(view,Layout.compact)
	layout["open"].erase("inspect"); layout["open"].append("inspect")
	layout["active"]="inspect"; layout["minimized"]["inspect"]=false
	layout["selection_seen"]=true
	ImmersiveWorkspace.save_layout(view,Layout.compact,layout)


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout.call_deferred()


func _relayout() -> void:
	_relayout_queued = false
	_build_layout()
	_refresh()


# --- Refresh -----------------------------------------------------------------------------------

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree() or _root == null:
		return
	state = Game.view()
	report = Economy.empire(state, state.player_id)
	_fix_selection()
	_top.set_model(GameModel.top_bar(state, report))
	for chip: Node in _top.find_children("*", "ResourceChip", true, false):
		var rc: ResourceChip = chip
		rc.opened.connect(ui_event.bind("breakdown_opened:" + rc.resource_id))
	_refresh_nav()
	_refresh_advisor()
	_refresh_view()
	_after_refresh.call_deferred()


func _fix_selection() -> void:
	var pid: String = state.player_id
	if not state.colonies.has(colony_id) or state.colonies[colony_id].owner_id != pid:
		var cap: Colony = GameModel.capital(state)
		colony_id = cap.id if cap != null else ""
	if not state.systems.has(system_id) and state.colonies.has(colony_id):
		system_id = state.planets[state.colonies[colony_id].planet_id].system_id
	if not planet_id.is_empty() and (not state.planets.has(planet_id) or state.planets[planet_id].system_id != system_id):
		planet_id = ""
	if view == MARKET and not Market.is_open(state, pid):
		view = COLONY
	var c: Colony = state.colonies.get(colony_id, null)
	if c == null or c.is_outpost() or slot >= ColonyRules.slot_count(state.planets[c.planet_id]):
		slot = -1


func _refresh_view() -> void:
	if immersive_active() != _immersive_layout:
		_build_layout()
		_top.set_model(GameModel.top_bar(state, report))
		_refresh_nav()
		_refresh_advisor()
	var keep: int = _scroll.scroll_vertical
	if view not in [SYSTEM, GALAXY, COLONY] or (view == COLONY and (not state.colonies.has(colony_id) or state.colonies[colony_id].is_outpost())) or Settings.appearance != "3d" or spatial_slice_enabled:
		world_controller.deactivate()
	for c: Node in _view_box.get_children():
		_view_box.remove_child(c)
		c.queue_free()
	var v: Control
	if _immersive_layout:
		v = ImmersiveWorldView.build(self)
	else:
		match view:
			GALAXY:
				v = GalaxyView.build(self)
			SYSTEM:
				v = SystemView.build(self)
			RESEARCH:
				v = ResearchView.build(self)
			ORDINANCES:
				v = OrdinancesView.build(self)
			MARKET:
				v = MarketView.build(self)
			OBJECTIVES:
				v = ObjectivesView.build(self)
			_:
				v = ColonyView.build(self)
	_view_box.add_child(v)
	_keep_scroll.call_deferred(keep)

func _world_selected(id: String) -> void:
	if _immersive_layout:
		if not id.is_empty(): reveal_immersive_inspector()
	if view == COLONY:
		if id.is_empty(): slot=-1; pick=""; _refresh_view()
		elif id.begins_with("slot:"): select_slot(int(id.trim_prefix("slot:")))
		return
	if view == GALAXY:
		if state.player().known_systems.has(id):
			system_id = id; planet_id = ""
			show_view(SYSTEM)
		else: Overlay.toast(Strings.fmt("ui.galaxy.locked_toast"), ReportItem.SEVERITY_INFO)
		return
	if state.colonies.has(id) and state.colonies[id].owner_id == state.player_id and not state.colonies[id].is_outpost():
		open_colony(id)
		return
	planet_id = id if state.planets.has(id) else ""
	_refresh_view()

func _world_setting_changed(key: String) -> void:
	if key == "view_mode":
		_queue_relayout()
	elif key=="interface_finish":
		_queue_refresh()
	elif key in ["appearance", "visual_quality"]:
		world_controller.deactivate()
		_queue_refresh()
	elif key=="high_contrast" and world_controller.host.renderer is ColonyRenderer:
		var city: ColonyRenderer=world_controller.host.renderer as ColonyRenderer
		if city.selected_slot>=0: city._highlight_selection()

func _world_new_session() -> void:
	planet_id = ""
	immersive_panel_open = false
	world_controller.deactivate()


func _keep_scroll(v: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = v


func _after_refresh() -> void:
	if not is_inside_tree() or state == null:
		return
	# A step that completes on the state completes the moment the orders make it true.
	if Settings.hints_enabled and not _step.is_empty():
		var cond: String = DictIO.str_of(DictIO.dict_of(_step, "complete_on"), "state")
		if not cond.is_empty() and Tutorial.condition_met(state, state.player_id, cond):
			_acknowledge(_step)
			return
	_apply_highlight()


# --- Navigation and selection ------------------------------------------------------------------

func _nav_items() -> Array[Array]:
	var out: Array[Array] = []
	for item: Array in NAV:
		var id: String = item[0]
		if id == MARKET and not Market.is_open(state, state.player_id):
			continue
		if Layout.compact and not TABS_COMPACT.has(id):
			continue
		if Layout.compact and Layout.logical_size.x<600.0 and id!=view:
			# Portrait keeps the current tab and all order controls in view.
			# The navigation drawer still exposes every other view by name.
			continue
		out.append(item)
	return out


func _refresh_nav() -> void:
	for c: Node in _nav_inner.get_children():
		_nav_inner.remove_child(c)
		c.queue_free()
	if _immersive_layout:
		ImmersiveWorldView.toolbar(self,_nav_inner)
		return
	var group: ButtonGroup = ButtonGroup.new()
	for item: Array in _nav_items():
		var id: String = item[0]
		var key: String = item[1]
		var icon: String = item[2]
		var b: SfButton = SfButton.make(key, icon, SfButton.TAB)
		b.name = "Nav_" + id
		b.button_group = group
		b.button_pressed = id == view
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(show_view.bind(id))
		if Layout.compact and (id != view or Layout.logical_size.x<600.0):
			# The tab bar is short of room, most of all at large text: only the open tab has a name.
			b.text = ""
			b.icon_only = true
			b.tooltip_text = Strings.fmt(key)
		_nav_inner.add_child(b)
	if Layout.compact:
		var more: SfButton = SfButton.make_icon("ui_menu", "ui.nav.more", SfButton.GHOST)
		more.name = "Nav_more"
		more.pressed.connect(open_more)
		_nav_inner.add_child(more)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_inner.add_child(spacer)
	var mode: SfButton = SfButton.make_icon("ui_display", "ui.world.enter_immersive", SfButton.GHOST) if Layout.compact else SfButton.make("ui.world.enter_immersive", "ui_display", SfButton.GHOST)
	mode.name = "ModeToggle"
	mode.pressed.connect(toggle_view_mode)
	mode.disabled = Settings.appearance != "3d" or view not in [COLONY,SYSTEM,GALAXY]
	_nav_inner.add_child(mode)
	var undo: SfButton = SfButton.make_icon("ui_undo", "ui.game.undo", SfButton.GHOST) if Layout.compact else SfButton.make("ui.game.undo", "ui_undo", SfButton.GHOST)
	undo.name = "Undo"
	undo.disabled = order_count() == 0
	undo.pressed.connect(undo_order)
	_nav_inner.add_child(undo)
	var end: SfButton = SfButton.make_icon("ui_end_turn","ui.game.end_turn",SfButton.PRIMARY) if Layout.compact else SfButton.make("ui.game.end_turn", "ui_end_turn", SfButton.PRIMARY)
	end.name = "EndTurn"
	end.pressed.connect(end_turn)
	_nav_inner.add_child(end)


func show_view(v: String) -> void:
	if _immersive_layout and v in [RESEARCH,ORDINANCES,MARKET,OBJECTIVES]:
		if v!=MARKET or Market.is_open(state,state.player_id): toggle_immersive_panel(v)
		return
	if view == v:
		return
	view = v
	Audio.play("ui_page_turn")
	_refresh_view()
	_refresh_nav()
	_after_refresh.call_deferred()


func select_planet(pid: String) -> void:
	planet_id = pid
	_refresh_view()


func open_planet(pid: String) -> void:
	if state.planets.has(pid):
		system_id = state.planets[pid].system_id
		planet_id = pid
	show_view(SYSTEM)
	_refresh_view()


func select_colony(cid: String) -> void:
	colony_id = cid
	slot = -1
	pick = ""
	_refresh_view()


func open_colony(cid: String) -> void:
	colony_id = cid
	slot = -1
	pick = ""
	if view == COLONY:
		_refresh_view()
	else:
		show_view(COLONY)


func select_slot(i: int) -> void:
	slot = i
	pick = ""
	if _immersive_layout: reveal_immersive_inspector()
	_refresh_view()


func set_pick(kind: String, id: String) -> void:
	pick_kind = kind
	pick = id
	_refresh_view()


func set_branch(branch: String) -> void:
	branch_pick = branch
	_refresh_view()


## Where a report line or a checklist line leads.
func jump(kind: String, id: String) -> void:
	Overlay.close_all()
	match kind:
		"colony":
			open_colony(id)
		"planet", "system":
			if state.planets.has(id):
				open_planet(id)
			else:
				if state.systems.has(id):
					system_id = id
				show_view(SYSTEM)
		"research":
			show_view(RESEARCH)
		"objective":
			show_view(OBJECTIVES)
		"event":
			next_event()


# --- Orders ------------------------------------------------------------------------------------

## Gives an order; when it is refused the reason appears as a notice.
func order(cmd: Command) -> Result:
	var r: Result = Game.submit(cmd)
	if not r.ok:
		Overlay.toast(GameUI.why(r), ReportItem.SEVERITY_WARNING)
	return r


## Orders given this turn, not counting the advisor's acknowledgements.
func order_count() -> int:
	var n: int = 0
	for c: Command in Game.queue.commands():
		if not c is AcknowledgeCommand:
			n += 1
	return n


## Takes back the latest order. Acknowledged tutorial steps come off with it; they return on
## their own while their condition still holds.
func undo_order() -> void:
	while true:
		var c: Command = Game.undo()
		if c == null or not c is AcknowledgeCommand:
			break
	Audio.play("ui_cancel")


# --- The advisor -------------------------------------------------------------------------------

func _refresh_advisor() -> void:
	for c: Node in _advisor_box.get_children():
		_advisor_box.remove_child(c)
		c.queue_free()
	_step = Tutorial.current(state) if Settings.hints_enabled else {}
	if _step.is_empty():
		return
	var advisor: String = BriefingScreen.ADVISOR
	var target: String = DictIO.str_of(_step, "highlight")
	var other_view: bool = HIGHLIGHT_VIEWS.has(target) and HIGHLIGHT_VIEWS[target] != view
	var text: Label = FlowScreen.label(Strings.fmt(DictIO.str_of(_step, "text_key")))
	text.name = "AdvisorText"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The step's own words: the scenario's teaching text, which may quote the rules' numbers.
	text.set_meta("audit_numeric_ok", "the tutorial's own text")
	if Layout.compact:
		# A phone has no room for a card: the portrait, the words and two small buttons in one strip.
		var strip: PanelContainer = PanelContainer.new()
		strip.name = "AdvisorCard"
		strip.theme_type_variation = &"InsetPanel"
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_M)
		row.add_child(Portrait.make(advisor, "neutral", 44.0))
		row.add_child(text)
		if other_view:
			var go_b: SfButton = SfButton.make_icon("ui_chevron_right", "ui.advisor.show")
			go_b.name = "ShowMe"
			go_b.pressed.connect(show_view.bind(HIGHLIGHT_VIEWS[target]))
			row.add_child(go_b)
		var ok: SfButton = SfButton.make_icon("ui_check", "ui.advisor.got_it")
		ok.name = "GotIt"
		ok.pressed.connect(_acknowledge.bind(_step))
		row.add_child(ok)
		strip.add_child(row)
		_advisor_box.add_child(strip)
		return
	var card: Card = Card.make(GameUI.name_of("portraits", advisor), Strings.fmt("ui.advisor.role"), "", "hearth.gold")
	card.name = "AdvisorCard"
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", Tokens.SPACE_M)
	row2.add_child(Portrait.make(advisor, "neutral", 72.0))
	row2.add_child(text)
	card.add_body(row2)
	var got: SfButton = SfButton.make("ui.advisor.got_it", "ui_check", SfButton.GHOST)
	got.name = "GotIt"
	got.pressed.connect(_acknowledge.bind(_step))
	card.add_action(got)
	if other_view:
		var show_b: SfButton = SfButton.make("ui.advisor.show", "ui_chevron_right", SfButton.SECONDARY)
		show_b.name = "ShowMe"
		show_b.pressed.connect(show_view.bind(HIGHLIGHT_VIEWS[target]))
		card.add_action(show_b)
	_advisor_box.add_child(card)


func _acknowledge(st: Dictionary) -> void:
	Game.submit(AcknowledgeCommand.create(state.player_id, DictIO.str_of(st, "id")))


## Something the player did that is not an order (closing the report, opening a breakdown).
func ui_event(what: String) -> void:
	if _step.is_empty() or not Settings.hints_enabled:
		return
	if DictIO.str_of(DictIO.dict_of(_step, "complete_on"), "ui") == what:
		_acknowledge(_step)


func _apply_highlight() -> void:
	var target: Control = null
	if not _step.is_empty():
		var node_name: String = HIGHLIGHTS.get(DictIO.str_of(_step, "highlight"), "")
		if not node_name.is_empty():
			target = find_child(node_name, true, false) as Control
			if target == null and node_name.begins_with("Nav_") and Layout.compact:
				target = find_child("Nav_more", true, false) as Control
	_ring.target = target


# --- End Turn and what follows -----------------------------------------------------------------

func end_turn() -> void:
	state = Game.view()
	report = Economy.empire(state, state.player_id)
	var checks: Array[ReportItem] = GameModel.end_turn_checks(state, report)
	for it: ReportItem in checks:
		if it.blocks_end_turn:
			next_event()
			return
	if checks.is_empty():
		resolve_turn()
	else:
		TurnReportOverlay.open_checklist(self, checks, resolve_turn)


func resolve_turn() -> void:
	Overlay.close_all()
	var r: TurnResult = Game.end_turn()
	if Game.state.is_over():
		go(AppRoot.DEBRIEF)
		return
	TurnReportOverlay.open_report(self, r.report_items, Strings.fmt("ui.report.turn_title"), next_event, Game.state.turn)


## Opens the first event waiting for an answer, and the next one when that is answered.
func next_event() -> void:
	var pending: Array[EventInstance] = Events.pending_for(Game.view(), Game.state.player_id)
	if pending.is_empty():
		return
	EventOverlay.open(self, pending[0].id, next_event)


func _start() -> void:
	if Game.last_result == null and Game.state.turn <= 1 and _opened_seed != Game.state.game_seed:
		_opened_seed = Game.state.game_seed
		TurnReportOverlay.open_report(self, GameModel.opening_report(state, report), Strings.fmt("ui.report.opening_title"), next_event)
	else:
		next_event()


func open_why(subject_kind: String, subject_id: String) -> void:
	WhyOverlay.open(subject_kind, subject_id)


# --- Menus -------------------------------------------------------------------------------------

func open_menu() -> void:
	var d: Drawer = Drawer.make(Strings.fmt("ui.game.menu"), Drawer.SIDE_RIGHT)
	d.name = "MenuDrawer"
	var entries: Array[Array] = [
		["ui.game.resume", "ui_play", Callable()],
		["ui.game.save", "ui_save", save_game],
		["ui.game.load", "ui_load", go.bind(AppRoot.LOAD, {"back": AppRoot.GAME})],
		["ui.game.codex", "ui_codex", CodexOverlay.open.bind("")],
		["ui.game.settings", "ui_settings", go.bind(AppRoot.SETTINGS, {"back": AppRoot.GAME})],
		["ui.game.quit", "ui_close", go.bind(AppRoot.TITLE)],
	]
	for e: Array in entries:
		var key: String = e[0]
		var icon: String = e[1]
		var cb: Callable = e[2]
		var b: SfButton = SfButton.make(key, icon, SfButton.GHOST)
		b.name = "Menu_" + key.get_slice(".", 2)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			d.close()
			if cb.is_valid():
				cb.call())
		d.body.add_child(b)
	d.body.add_child(GameUI.caption(Strings.fmt("ui.game.save_note")))
	d.open()


## Phones: the views that do not fit the tab bar, and the menu.
func open_more() -> void:
	var d: Drawer = Drawer.make(Strings.fmt("ui.nav.more_title"), Drawer.SIDE_RIGHT)
	d.name = "MoreViews"
	for item: Array in NAV:
		var id: String = item[0]
		var in_bar: bool=TABS_COMPACT.has(id) if Layout.logical_size.x>=600.0 else id==view
		if (in_bar and not _immersive_layout) or (id == MARKET and not Market.is_open(state, state.player_id)):
			continue
		var key: String = item[1]
		var icon: String = item[2]
		var b: SfButton = SfButton.make(key, icon, SfButton.GHOST)
		b.name = "More_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			d.close()
			show_view(id))
		d.body.add_child(b)
	var menu_b: SfButton = SfButton.make("ui.game.menu", "ui_settings", SfButton.GHOST)
	menu_b.name = "More_menu"
	menu_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_b.pressed.connect(func() -> void:
		d.close()
		open_menu())
	d.body.add_child(menu_b)
	d.open()


## A manual save of the game as it stands (this turn's unspent orders are not part of it).
func save_game() -> void:
	var slot_name: String = SaveService.save_manual(Game.state)
	if slot_name.is_empty():
		Overlay.toast(Strings.fmt("ui.game.save_failed"), ReportItem.SEVERITY_WARNING)
	else:
		Overlay.toast(Strings.fmt("ui.game.saved"), ReportItem.SEVERITY_GOOD)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10 and Overlay.stack_size() == 0:
		if Settings.appearance == "3d" and view in [COLONY,SYSTEM,GALAXY]:
			toggle_view_mode()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and Overlay.stack_size() == 0 and Overlay.open_tooltips().is_empty():
		get_viewport().set_input_as_handled()
		if _immersive_layout and immersive_panel_open: close_immersive_panel()
		else: open_menu()


## Puts the screen in a named state for tests and the screenshot tour.
func demo(state_name: String) -> void:
	Overlay.close_all()
	match state_name:
		"galaxy", "system", "colony", "research", "ordinances", "market", "objectives":
			view = ""
			show_view(state_name)
		"planet":
			open_planet("pl_brume")
		"slot":
			view = ""
			show_view(COLONY)
			var c: Colony = state.colonies.get(colony_id, null)
			if c != null:
				for i: int in ColonyRules.free_slots(c, state.planets[c.planet_id]):
					select_slot(i)
					set_pick("district", "agriculture")
					break
		"event":
			next_event()
		"report":
			if Game.last_result != null:
				TurnReportOverlay.open_report(self, Game.last_result.report_items, Strings.fmt("ui.report.turn_title"), Callable(), Game.state.turn)
			else:
				TurnReportOverlay.open_report(self, GameModel.opening_report(state, report), Strings.fmt("ui.report.opening_title"), Callable())
		"checklist":
			TurnReportOverlay.open_checklist(self, GameModel.end_turn_checks(state, report), Callable())
		"menu":
			open_menu()
		"more":
			open_more()
		"why":
			open_why("colony", colony_id)
	await get_tree().process_frame
	await get_tree().process_frame
