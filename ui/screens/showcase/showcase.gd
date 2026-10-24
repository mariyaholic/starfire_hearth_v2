extends Control
## The M0 UI kit showcase: every component on sample data, the icon contact sheet, and the star
## and planet generators. It is the main scene of the M0 build so the Owner can judge the look on a
## PC and on a phone. The toolbar switches text size (100-200%), high contrast, reduce motion and
## the layout profile (Auto, PC, Phone) live.
## demo(name) puts the screen in a named state for the screenshot tour. Opened from the title
## (a debug entry) it shows a Back button that emits back_requested.

signal back_requested

const PAGES: Array[String] = ["components", "icons", "worlds"]

var page: String = "components"
## Set by the AppRoot before the showcase enters the tree.
var show_back: bool = false
var _top_bar: TopBar
var _toolbar: HFlowContainer
var _page_host: MarginContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _explain_food: Explainable
var _rebuild_queued: bool = false


func _ready() -> void:
	name = "Showcase"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("separation", 0)
	add_child(_content)
	Layout.changed.connect(_queue_rebuild)
	_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	(get_node("Background") as ColorRect).color = Tokens.color("bg.deep")
	var m: Vector4 = Layout.safe_margins
	_content.offset_left = 0
	_content.offset_top = m.y
	_content.offset_right = -m.z
	_content.offset_bottom = -m.w
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_top_bar = TopBar.new()
	_top_bar.set_model(ShowcaseData.top_bar(Game.db))
	_top_bar.menu_pressed.connect(_open_options_drawer)
	_content.add_child(_top_bar)
	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad: int = Tokens.SPACE_M if Layout.compact else Tokens.SPACE_XL
	body.add_theme_constant_override("margin_left", pad + int(m.x))
	body.add_theme_constant_override("margin_right", pad)
	body.add_theme_constant_override("margin_top", Tokens.SPACE_M)
	body.add_theme_constant_override("margin_bottom", 0)
	_content.add_child(body)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_M)
	body.add_child(col)
	col.add_child(_make_toolbar())
	_scroll = ScrollContainer.new()
	_scroll.name = "PageScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	var page_root: Control
	match page:
		"icons":
			page_root = ShowcaseIcons.build()
		"worlds":
			page_root = ShowcaseWorlds.build(Game.db)
		_:
			page_root = _components_page()
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bottom_pad: MarginContainer = MarginContainer.new()
	bottom_pad.add_theme_constant_override("margin_bottom", Tokens.SPACE_XXL)
	bottom_pad.add_child(page_root)
	bottom_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(bottom_pad)


# --- toolbar ------------------------------------------------------------------------------------

func _make_toolbar() -> Control:
	_toolbar = HFlowContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	_toolbar.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	if show_back:
		var back: SfButton = SfButton.make("ui.flow.back", "ui_back", SfButton.GHOST)
		back.name = "Back"
		back.pressed.connect(func() -> void: back_requested.emit())
		_toolbar.add_child(back)
	var group: ButtonGroup = ButtonGroup.new()
	var keys: Dictionary[String, String] = {"components": "ui.showcase.page.components", "icons": "ui.showcase.page.icons", "worlds": "ui.showcase.page.worlds"}
	var icons: Dictionary[String, String] = {"components": "district_habitation", "icons": "emblem_hearth", "worlds": "planet_gas_giant"}
	for p: String in PAGES:
		var b: SfButton = SfButton.make(keys[p], icons[p], SfButton.TAB)
		b.name = "Page_" + p
		b.button_group = group
		b.button_pressed = p == page
		b.pressed.connect(show_page.bind(p))
		_toolbar.add_child(b)
	if not Layout.compact:
		var sep: VSeparator = VSeparator.new()
		_toolbar.add_child(sep)
		_add_options(_toolbar)
	else:
		var opts: SfButton = SfButton.make("ui.showcase.options", "ui_settings", SfButton.GHOST)
		opts.name = "Options"
		opts.pressed.connect(_open_options_drawer)
		_toolbar.add_child(opts)
	return _toolbar


func _add_options(into: Container) -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for pair: Array in [[1.0, "ui.showcase.text_100"], [1.5, "ui.showcase.text_150"], [2.0, "ui.showcase.text_200"]]:
		var b: SfButton = SfButton.make(pair[1], "", SfButton.TAB)
		b.set_meta("audit_numeric_ok", "text size setting, not a game quantity")
		b.button_group = group
		b.button_pressed = is_equal_approx(Settings.text_scale, pair[0])
		b.pressed.connect(Settings.set_text_scale.bind(pair[0]))
		into.add_child(b)
	var hc: CheckButton = CheckButton.new()
	hc.text = Strings.fmt("ui.showcase.high_contrast")
	hc.button_pressed = Settings.high_contrast
	hc.toggled.connect(Settings.set_high_contrast)
	hc.custom_minimum_size.y = Layout.target_size()
	into.add_child(hc)
	var rm: CheckButton = CheckButton.new()
	rm.text = Strings.fmt("ui.showcase.reduce_motion")
	rm.button_pressed = Settings.reduce_motion
	rm.toggled.connect(Settings.set_reduce_motion)
	rm.custom_minimum_size.y = Layout.target_size()
	into.add_child(rm)
	var lgroup: ButtonGroup = ButtonGroup.new()
	for pair: Array in [[Layout.Profile.AUTO, "ui.showcase.layout_auto"], [Layout.Profile.PC, "ui.showcase.layout_pc"], [Layout.Profile.PHONE, "ui.showcase.layout_phone"]]:
		var b: SfButton = SfButton.make(pair[1], "", SfButton.TAB)
		b.button_group = lgroup
		b.button_pressed = Layout.profile == pair[0]
		b.pressed.connect(Layout.set_profile.bind(pair[0]))
		into.add_child(b)


func _open_options_drawer() -> void:
	var d: Drawer = Drawer.make(Strings.fmt("ui.showcase.options"), Drawer.SIDE_RIGHT)
	var flow: HFlowContainer = HFlowContainer.new()
	d.body.add_child(flow)
	_add_options(flow)
	d.open()


func show_page(p: String) -> void:
	if page == p:
		return
	page = p
	_queue_rebuild()


# --- components page ----------------------------------------------------------------------------

func _components_page() -> Control:
	var cards: Array[Control] = [
		_card_intro(),
		_card_numbers(),
		_card_resources(),
		_card_buttons(),
		_card_hexes(),
		_card_event(),
		_card_report(),
		_card_overlays(),
		_card_type(),
	]
	var columns: int = 1
	if not Layout.compact:
		columns = clampi(int(Layout.logical_size.x / 560.0), 1, 3)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_L)
	var cols: Array[VBoxContainer] = []
	for i in columns:
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", Tokens.SPACE_L)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		cols.append(v)
	for i in cards.size():
		cols[i % columns].add_child(cards[i])
	return row


func _card_intro() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.title"), Strings.fmt("ui.showcase.subtitle"), "emblem_hearth", "hearth.gold")
	c.name = "CardIntro"
	c.add_text(Strings.fmt("ui.showcase.intro"), &"SecondaryLabel")
	return c


func _card_numbers() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.numbers.title"), Strings.fmt("ui.showcase.numbers.subtitle"), "ui_why", "accent.teal")
	c.name = "CardNumbers"
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	c.add_body(grid)
	_explain_food = _stat_row(grid, "ui.showcase.numbers.food", ShowcaseData.food(), "res_food", "ok.green")
	_stat_row(grid, "ui.showcase.numbers.stability", ShowcaseData.stability(), "stat_stability", "text.primary")
	_stat_row(grid, "ui.showcase.numbers.research_cost", ShowcaseData.research_cost(), "res_research", "sci.cyan")
	_stat_row(grid, "ui.showcase.numbers.noise", ShowcaseData.noise(), "stat_noise", "sci.cyan")
	var hint: Label = c.add_text(Strings.fmt("ui.showcase.numbers.hint_touch" if Layout.touch_ui else "ui.showcase.numbers.hint_pointer"), &"CaptionLabel")
	hint.name = "Hint"
	return c


func _stat_row(grid: GridContainer, label_key: String, b: Breakdown, icon: String, token: String) -> Explainable:
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(SfIcon.make(icon, Tokens.ICON_M, token))
	var l: Label = Label.new()
	l.text = Strings.fmt(label_key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(l)
	grid.add_child(name_row)
	var v: Label = Label.new()
	v.theme_type_variation = &"MonoStrongLabel"
	v.text = Fmt.total(b) + Fmt.suffix(b)
	var e: Explainable = Explainable.wrap(v, b)
	e.custom_minimum_size.y = Layout.target_size()
	e.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_child(e)
	return e


func _card_resources() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.resources.title"), Strings.fmt("ui.showcase.resources.subtitle"), "res_minerals", "mineral.slate")
	c.name = "CardResources"
	var model: TopBar.Model = ShowcaseData.top_bar(Game.db)
	var flow: HFlowContainer = HFlowContainer.new()
	for rid: String in model.resource_order:
		var r: Dictionary = model.resources[rid]
		var chip: ResourceChip = ResourceChip.make_chip(rid, r["icon"], r["color"], int(r["stock"]), int(r["net"]), r["breakdown"])
		if int(r["stock"]) < 0:
			chip.hide_stock()
		if rid == "food":
			chip.set_warning(true)
		flow.add_child(chip)
	c.add_body(flow)
	var warn: Label = c.add_text(Strings.fmt("ui.showcase.resources.warning"), &"CaptionLabel")
	warn.name = "WarningNote"
	var stab: Breakdown = ShowcaseData.stability()
	c.add_body(_meter_row("ui.showcase.resources.stability", Meter.make(float(stab.total), 100.0, "hearth.gold", [15.0, 30.0, 70.0], [{"at": 0.0, "token": "alert.ember"}, {"at": 31.0, "token": "hearth.gold"}, {"at": 70.0, "token": "ok.green"}]), stab))
	var names: Dictionary[String, String] = {"physics": "ui.showcase.resources.physics", "society": "ui.showcase.resources.society", "engineering": "ui.showcase.resources.engineering"}
	var progress: Dictionary[String, int] = {"physics": 62, "society": 25, "engineering": 88}
	for branch: String in ["physics", "society", "engineering"]:
		var pb: Breakdown = Breakdown.make("breakdown.card_progress", Breakdown.UNIT_PERCENT, false, {"branch_key": names[branch]})
		pb.base("source.progress", progress[branch] * 100)
		pb.finish()
		c.add_body(_meter_row(names[branch], Meter.make(float(progress[branch]), 100.0, "sci.cyan"), pb, "branch_" + branch))
	return c


func _meter_row(label_key: String, m: Meter, b: Breakdown, icon: String = "stat_stability") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(SfIcon.make(icon, Tokens.ICON_M, "text.secondary"))
	var l: Label = Label.new()
	l.text = Strings.fmt(label_key)
	l.custom_minimum_size.x = 110
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(m)
	var v: Label = Label.new()
	v.theme_type_variation = &"MonoLabel"
	v.text = Fmt.total(b)
	var e: Explainable = Explainable.wrap(v, b)
	e.custom_minimum_size = Vector2(56, Layout.target_size())
	row.add_child(e)
	return row


func _card_buttons() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.buttons.title"), Strings.fmt("ui.showcase.buttons.subtitle"), "ui_end_turn", "accent.teal")
	c.name = "CardButtons"
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_child(SfButton.make("ui.showcase.buttons.end_turn", "ui_end_turn", SfButton.PRIMARY))
	flow.add_child(SfButton.make("ui.showcase.buttons.planner", "ui_colony", SfButton.SECONDARY))
	flow.add_child(SfButton.make("ui.showcase.buttons.codex", "ui_codex", SfButton.GHOST))
	flow.add_child(SfButton.make("ui.showcase.buttons.war", "stance_aggressive", SfButton.DANGER))
	c.add_body(flow)
	var icons: HFlowContainer = HFlowContainer.new()
	for pair: Array in [["ui_menu", "ui.topbar.menu"], ["ui_settings", "ui.showcase.options"], ["ui_search", "ui.showcase.buttons.search"], ["ui_undo", "ui.showcase.buttons.undo"], ["ui_pin", "ui.showcase.buttons.pin"], ["ui_why", "ui.showcase.buttons.why"], ["ui_close", "ui.overlay.close"]]:
		icons.add_child(SfButton.make_icon(pair[0], pair[1]))
	c.add_body(icons)
	var blocked: SfButton = SfButton.make("ui.showcase.buttons.build", "district_industry", SfButton.PRIMARY)
	blocked.disabled = true
	c.add_body(blocked)
	var why: HBoxContainer = HBoxContainer.new()
	why.add_child(SfIcon.make("alert_warning", Tokens.ICON_S, "hearth.gold"))
	var wl: Label = Label.new()
	wl.theme_type_variation = &"CaptionLabel"
	wl.text = Strings.fmt("ui.showcase.buttons.build_reason")
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.add_child(wl)
	c.add_body(why)
	var tabs: SfTabs = SfTabs.new()
	for pair: Array in [["ui.showcase.tabs.colonies", "ui.showcase.tabs.colonies_body"], ["ui.showcase.tabs.research", "ui.showcase.tabs.research_body"], ["ui.showcase.tabs.fleets", "ui.showcase.tabs.fleets_body"]]:
		var p: Label = Label.new()
		p.text = Strings.fmt(pair[1])
		p.theme_type_variation = &"SecondaryLabel"
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tabs.add_tab(pair[0], p)
	c.add_body(tabs)
	return c


func _card_hexes() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.hex.title"), Strings.fmt("ui.showcase.hex.subtitle"), "district_habitation", "accent.teal")
	c.name = "CardHexes"
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	flow.add_theme_constant_override("v_separation", Tokens.SPACE_L)
	var r: float = 30.0 if Layout.compact else 34.0
	for id: String in Game.db.ids("districts"):
		var rec: Dictionary = Game.db.record("districts", id)
		flow.add_child(_hex_item(HexCell.for_district(id, rec["icon"], 1 + (Game.db.ids("districts").find(id) % 3)), Strings.fmt(rec["name_key"]), r))
	var empty: HexCell = HexCell.new()
	flow.add_child(_hex_item(empty, Strings.fmt("ui.showcase.hex.empty"), r))
	var blocked: HexCell = HexCell.new()
	blocked.state = HexCell.STATE_BLOCKED
	flow.add_child(_hex_item(blocked, Strings.fmt("ui.showcase.hex.blocked"), r))
	var building: HexCell = HexCell.for_district("industry", "district_industry", 1, HexCell.STATE_BUILDING)
	building.progress = 60
	flow.add_child(_hex_item(building, Strings.fmt("ui.showcase.hex.building"), r))
	var ghost: HexCell = HexCell.for_district("research", "district_research", 1, HexCell.STATE_GHOST)
	ghost.deltas = [{"text": "+10%", "positive": true}, {"text": Fmt.points(-2), "positive": false}]
	flow.add_child(_hex_item(ghost, Strings.fmt("ui.showcase.hex.ghost"), r))
	var sel: HexCell = HexCell.for_district("agriculture", "district_agriculture", 2)
	sel.selected = true
	flow.add_child(_hex_item(sel, Strings.fmt("ui.showcase.hex.selected"), r))
	c.add_body(flow)
	c.add_text(Strings.fmt("ui.showcase.hex.note"), &"CaptionLabel")
	return c


func _hex_item(h: HexCell, caption: String, r: float) -> VBoxContainer:
	h.radius = r
	var cap_w: float = (HexCell.cell_size(r).x + 24.0) * Settings.text_scale
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	v.custom_minimum_size.x = cap_w
	var wrap: CenterContainer = CenterContainer.new()
	wrap.add_child(h)
	v.add_child(wrap)
	var l: Label = Label.new()
	l.theme_type_variation = &"CaptionLabel"
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = cap_w
	v.add_child(l)
	return v


func _card_event() -> Card:
	var c: Card = Card.make(Strings.fmt("sample.event.title"), Strings.fmt("sample.event.speaker"), "ui_event", "hearth.gold")
	c.name = "CardEvent"
	c.add_body(StoryScene.make("founders_hall", 150.0))
	c.add_text(Strings.fmt("sample.event.body"))
	var council: Breakdown = Breakdown.for_resource("breakdown.choice_effect", "influence", true)
	council.base("source.choice_effect", 100, {"effect_key": "sample.event.effect_council"}).finish()
	var steward: Breakdown = Breakdown.make("breakdown.choice_effect", Breakdown.UNIT_POINTS)
	steward.base("source.choice_effect", 5, {"effect_key": "sample.event.effect_steward"}).finish()
	c.add_body(_choice("sample.event.choice_council", [["res_influence", "influence.violet", -3000]], "sample.event.effect_council", council))
	c.add_body(_choice("sample.event.choice_steward", [["res_energy", "energy.yellow", -2000]], "sample.event.effect_steward", steward))
	c.add_body(_choice("sample.event.choice_assembly", [], "sample.event.effect_assembly", null))
	return c


func _choice(label_key: String, costs: Array, effect_key: String, effect: Breakdown) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	var b: SfButton = SfButton.make(label_key, "", SfButton.SECONDARY)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(b)
	var row: HFlowContainer = HFlowContainer.new()
	for cost: Array in costs:
		var chip: PanelContainer = PanelContainer.new()
		chip.theme_type_variation = &"ChipPanel"
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", Tokens.SPACE_XS)
		h.add_child(SfIcon.make(cost[0], Tokens.ICON_S, cost[1]))
		var t: Label = Label.new()
		t.theme_type_variation = &"MonoCaptionLabel"
		t.text = Fmt.centi(int(cost[2]), true, 0)
		h.add_child(t)
		chip.add_child(h)
		var bd: Breakdown = Breakdown.make("breakdown.choice_cost", Breakdown.UNIT_CENTI)
		bd.base("source.choice", int(cost[2]))
		bd.finish()
		row.add_child(Explainable.wrap(chip, bd))
	var eff: Label = Label.new()
	eff.theme_type_variation = &"CaptionLabel"
	eff.text = Strings.fmt(effect_key)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eff)
	if effect != null:
		var val: Label = Label.new()
		val.theme_type_variation = &"MonoCaptionLabel"
		val.text = Fmt.line_value(effect, effect.total) + (" " + Strings.fmt("ui.fmt.per_turn") if effect.per_turn else "")
		val.add_theme_color_override("font_color", Tokens.color(Tokens.POSITIVE))
		row.add_child(Explainable.wrap(val, effect))
	v.add_child(row)
	return v


func _card_report() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.report.title"), Strings.fmt("ui.showcase.report.subtitle"), "ui_report", "accent.teal")
	c.name = "CardReport"
	var items: Array[ReportItem] = ShowcaseData.report_items()
	var top: Array[ReportItem] = ReportBuilder.top(items)
	for it: ReportItem in top:
		c.add_body(_report_row(it, true))
	var groups: Dictionary[String, Array] = ReportBuilder.grouped(items)
	var cat_keys: Dictionary[String, String] = {"colonies": "ui.report.category.colonies", "research": "ui.report.category.research", "fleets": "ui.report.category.fleets", "diplomacy": "ui.report.category.diplomacy", "story": "ui.report.category.story"}
	for cat: String in groups.keys():
		var rest: Array[ReportItem] = []
		for it: Variant in groups[cat]:
			if not top.has(it):
				rest.append(it)
		if rest.is_empty():
			continue
		var h: Label = Label.new()
		h.theme_type_variation = &"CaptionLabel"
		h.text = Strings.fmt(cat_keys[cat]).to_upper()
		c.add_body(h)
		for it: ReportItem in rest:
			c.add_body(_report_row(it, false))
	return c


func _report_row(it: ReportItem, strong: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	row.add_child(SfIcon.make(Toast.ICONS.get(it.severity, "alert_info"), Tokens.ICON_M, Toast.COLORS.get(it.severity, "accent.teal")))
	var l: Label = Label.new()
	l.text = Strings.fmt(it.text_key, it.args)
	l.theme_type_variation = &"StrongLabel" if strong else &""
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var content: Control = l
	if it.breakdown != null:
		content = Explainable.wrap(l, it.breakdown, false)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	row.add_child(SfButton.make_icon("ui_chevron_right", "ui.report.jump"))
	return row


func _card_overlays() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.overlays.title"), Strings.fmt("ui.showcase.overlays.subtitle"), "ui_diplomacy", "accent.teal")
	c.name = "CardOverlays"
	var flow: HFlowContainer = HFlowContainer.new()
	var modal_b: SfButton = SfButton.make("ui.showcase.overlays.modal", "ui_event")
	modal_b.pressed.connect(func() -> void: demo("modal"))
	flow.add_child(modal_b)
	var drawer_b: SfButton = SfButton.make("ui.showcase.overlays.drawer", "ui_menu")
	drawer_b.pressed.connect(func() -> void: demo("drawer"))
	flow.add_child(drawer_b)
	var sheet_b: SfButton = SfButton.make("ui.showcase.overlays.sheet", "ship_fleet")
	sheet_b.pressed.connect(func() -> void: demo("sheet"))
	flow.add_child(sheet_b)
	var toast_b: SfButton = SfButton.make("ui.showcase.overlays.toasts", "alert_info")
	toast_b.pressed.connect(func() -> void: demo("toasts"))
	flow.add_child(toast_b)
	var tip_b: SfButton = SfButton.make("ui.showcase.overlays.tooltip", "ui_pin")
	tip_b.pressed.connect(func() -> void: demo("tooltip"))
	flow.add_child(tip_b)
	c.add_body(flow)
	return c


func _card_type() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.showcase.type.title"), Strings.fmt("ui.showcase.type.subtitle"), "ui_codex", "accent.teal")
	c.name = "CardType"
	for pair: Array in [[&"DisplayLabel", "ui.showcase.type.display"], [&"H1Label", "ui.showcase.type.h1"], [&"H2Label", "ui.showcase.type.h2"], [&"", "ui.showcase.type.body"], [&"CaptionLabel", "ui.showcase.type.caption"]]:
		var l: Label = Label.new()
		l.theme_type_variation = pair[0]
		l.text = Strings.fmt(pair[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_body(l)
	var sw: HFlowContainer = HFlowContainer.new()
	sw.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	var names: Dictionary[String, String] = {
		"bg.deep": "ui.token.bg_deep", "bg.panel": "ui.token.bg_panel", "bg.panel.alt": "ui.token.bg_panel_alt",
		"line.subtle": "ui.token.line_subtle", "text.primary": "ui.token.text_primary", "text.secondary": "ui.token.text_secondary",
		"accent.teal": "ui.token.accent_teal", "hearth.gold": "ui.token.hearth_gold", "alert.ember": "ui.token.alert_ember",
		"ally.blue": "ui.token.ally_blue", "other.magenta": "ui.token.other_magenta", "ok.green": "ui.token.ok_green",
		"energy.yellow": "ui.token.energy_yellow", "mineral.slate": "ui.token.mineral_slate", "alloy.copper": "ui.token.alloy_copper",
		"sci.cyan": "ui.token.sci_cyan", "influence.violet": "ui.token.influence_violet",
	}
	for token: String in Tokens.PALETTE.keys():
		sw.add_child(_swatch(token, Strings.fmt(names[token])))
	c.add_body(sw)
	return c


func _swatch(token: String, label_text: String) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	v.custom_minimum_size.x = 96.0 * Settings.text_scale
	var chip: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Tokens.color(token)
	sb.set_corner_radius_all(Tokens.RADIUS_CHIP)
	sb.border_color = Tokens.color("line.subtle")
	sb.set_border_width_all(1)
	chip.add_theme_stylebox_override("panel", sb)
	chip.custom_minimum_size = Vector2(96, 32)
	v.add_child(chip)
	var l: Label = Label.new()
	l.theme_type_variation = &"CaptionLabel"
	l.text = label_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 96.0 * Settings.text_scale
	v.add_child(l)
	return v


# --- demo states for the screenshot tour --------------------------------------------------------

## Puts the showcase in a named state: tooltip, modal, drawer, sheet, toasts, or a page name.
func demo(state_name: String) -> void:
	Overlay.close_all()
	match state_name:
		"tooltip":
			if _explain_food != null:
				var tip: BreakdownTooltip = _explain_food.open_pinned()
				await get_tree().process_frame
				await get_tree().process_frame
				if tip != null:
					var nested: Array[Node] = tip.find_children("*", "Explainable", true, false)
					if not nested.is_empty():
						(nested[0] as Explainable).open_pinned()
		"modal":
			var m: Modal = Modal.make(Strings.fmt("sample.modal.title"))
			var p: Label = Label.new()
			p.text = Strings.fmt("sample.modal.body")
			p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			m.body.add_child(p)
			m.body.add_child(StoryScene.make("sealed_archive", 150.0))
			var ok: SfButton = SfButton.make("sample.modal.accept", "ui_check", SfButton.PRIMARY)
			ok.pressed.connect(m.close)
			m.add_action(SfButton.make("sample.modal.later", "", SfButton.GHOST))
			m.add_action(ok)
			m.open()
		"drawer":
			var d: Drawer = Drawer.make(Strings.fmt("sample.drawer.title"), Drawer.SIDE_LEFT)
			for pair: Array in [["ui_colony", "planet.aster.name"], ["ui_colony", "planet.brume.name"], ["map_outpost", "planet.dross.name"], ["ship_survey", "sample.drawer.probe"], ["ship_construction", "sample.drawer.constructor"]]:
				var b: SfButton = SfButton.make(pair[1], pair[0], SfButton.GHOST)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				d.body.add_child(b)
			d.open()
		"sheet":
			var s: BottomSheet = BottomSheet.make(Strings.fmt("system.ember.name"), BottomSheet.FIT)
			var row: HBoxContainer = HBoxContainer.new()
			row.add_child(StarDisc.make("K", 3, 72))
			var t: Label = Label.new()
			t.text = Strings.fmt("sample.sheet.body")
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(t)
			s.body.add_child(row)
			var acts: HFlowContainer = HFlowContainer.new()
			acts.add_child(SfButton.make("sample.sheet.enter", "ui_chevron_right", SfButton.PRIMARY))
			acts.add_child(SfButton.make("sample.sheet.survey", "ship_survey"))
			s.body.add_child(acts)
			s.open()
		"toasts":
			Overlay.toast(Strings.fmt("sample.toast.info"), ReportItem.SEVERITY_INFO, 0.0)
			Overlay.toast(Strings.fmt("sample.toast.good"), ReportItem.SEVERITY_GOOD, 0.0)
			Overlay.toast(Strings.fmt("sample.toast.warning"), ReportItem.SEVERITY_WARNING, 0.0)
		"more":
			_top_bar.open_more()
		"components", "icons", "worlds":
			page = state_name
			_rebuild()


## Scrolls the components page so the named card is at the top.
func scroll_to_card(card_name: String) -> void:
	var card: Node = find_child(card_name, true, false)
	if card is Control and _scroll != null:
		_scroll.scroll_vertical = int((card as Control).global_position.y - _scroll.global_position.y + _scroll.scroll_vertical - Tokens.SPACE_S)
