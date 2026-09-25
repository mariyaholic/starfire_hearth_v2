class_name TitleScreen
extends FlowScreen
## The title screen (§7 screen 1): the game's name over the sky (the painted key art and logo once
## they are delivered) and the main menu. Continue opens the newest save that loads. A menu entry
## appears only when its screen exists, so nothing leads nowhere; Quit appears on desktop only.

## Routes the AppRoot can open.
var routes: Array[String] = []
## The newest save that loads: {"slot", "state"}, or empty.
var _newest: Dictionary = {}


static func make(p_routes: Array[String]) -> TitleScreen:
	var s: TitleScreen = TitleScreen.new()
	s.name = "TitleScreen"
	s.routes = p_routes
	s._newest = _find_newest()
	return s


func make_backdrop() -> Control:
	var art: Texture2D = AssetIds.texture("title")
	if art == null:
		return Starfield.new()
	var tr: TextureRect = TextureRect.new()
	tr.texture = art
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func has_continue() -> bool:
	return not _newest.is_empty()


func build_screen() -> void:
	var menu: VBoxContainer = _menu()
	if Layout.compact:
		# A landscape phone: the name on the left, the menu on the right, scrolling if it must.
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_L)
		frame.add_child(row)
		var left: VBoxContainer = _name_block()
		# Wrapping labels need a width to wrap in; a centring container would give them none.
		left.custom_minimum_size.x = clampf(Layout.logical_size.x * 0.4, 240.0, 460.0)
		left.add_child(_version())
		var left_box: CenterContainer = _centred(FlowScreen.scrim(left))
		left_box.size_flags_stretch_ratio = 1.2
		row.add_child(left_box)
		var sc: ScrollContainer = FlowScreen.scroll_of(_centred(FlowScreen.scrim(menu)))
		sc.size_flags_stretch_ratio = 1.0
		row.add_child(sc)
	else:
		var col: VBoxContainer = VBoxContainer.new()
		frame.add_child(col)
		var block: CenterContainer = _centred(FlowScreen.scrim(_pc_column(menu)))
		if AssetIds.is_delivered("title"):
			# The key art keeps its left 40% calm for the menu (§15.9): the column sits there.
			var row2: HBoxContainer = HBoxContainer.new()
			row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
			block.size_flags_stretch_ratio = 0.4
			row2.add_child(block)
			var rest: Control = Control.new()
			rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rest.size_flags_stretch_ratio = 0.6
			rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row2.add_child(rest)
			col.add_child(FlowScreen.scroll_of(row2))
		else:
			col.add_child(FlowScreen.scroll_of(block))
		var v: Label = _version()
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(v)
	var first: Control = menu.get_child(0) as Control
	if first != null and not Layout.touch_ui:
		first.grab_focus.call_deferred()


func _pc_column(menu: VBoxContainer) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_XXL)
	col.custom_minimum_size.x = clampf(Layout.logical_size.x * 0.3, 380.0, 560.0)
	col.add_child(_name_block())
	col.add_child(menu)
	return col


## Centres a block vertically in whatever space it gets, and lets it grow past it (then it scrolls).
static func _centred(block: Control) -> CenterContainer:
	var cc: CenterContainer = CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc.add_child(block)
	return cc


func _name_block() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "NameBlock"
	v.add_theme_constant_override("separation", Tokens.SPACE_S)
	# The painted title logo if there is one, else the flat vector logo, else the name as text.
	var logo: Texture2D = AssetIds.texture("logo_title")
	if logo == null:
		logo = AssetIds.texture("logo_light_on_dark")
	if logo != null:
		var tr: TextureRect = TextureRect.new()
		tr.name = "Logo"
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.custom_minimum_size = Vector2(0, 88 if Layout.compact else 128)
		v.add_child(tr)
	else:
		var t: Label = FlowScreen.label(Strings.fmt("ui.title.name"), &"DisplayLabel")
		t.name = "GameName"
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_color_override("font_color", Tokens.color("hearth.gold"))
		v.add_child(t)
	var tag: Label = FlowScreen.label(Strings.fmt("ui.title.tagline"), &"SecondaryLabel")
	tag.name = "Tagline"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	return v


func _menu() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Menu"
	v.add_theme_constant_override("separation", Tokens.SPACE_S)
	v.custom_minimum_size.x = 260.0 if Layout.compact else 0.0
	if has_continue():
		var cont: SfButton = _item(v, "ui.title.continue", "ui_play", SfButton.PRIMARY, "continue")
		cont.name = "Continue"
		var st: GameState = _newest["state"]
		var detail: Label = FlowScreen.label(Strings.fmt("ui.title.continue_detail", {"scenario_key": _scenario_name_key(st.scenario_id), "date": Fmt.date(st.turn)}), &"CaptionLabel")
		detail.name = "ContinueDetail"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.set_meta("audit_numeric_ok", "the saved game's date")
		v.add_child(detail)
	var camp: SfButton = _item(v, "ui.title.campaign", "ui_star", SfButton.SECONDARY if has_continue() else SfButton.PRIMARY, AppRoot.CAMPAIGN)
	camp.name = "Campaign"
	for entry: Array in [[AppRoot.LOAD, "ui.title.load", "ui_load"], [AppRoot.CODEX, "ui.title.codex", "ui_codex"], [AppRoot.SETTINGS, "ui.title.settings", "ui_settings"], [AppRoot.SHOWCASE, "ui.title.showcase", "ui_display"]]:
		var route: String = entry[0]
		if routes.has(route):
			var b: SfButton = _item(v, entry[1], entry[2], SfButton.GHOST, route)
			b.name = route.capitalize()
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var q: SfButton = SfButton.make("ui.title.quit", "ui_close", SfButton.GHOST)
		q.name = "Quit"
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q.pressed.connect(func() -> void: get_tree().quit())
		v.add_child(q)
	return v


func _item(into: VBoxContainer, key: String, icon: String, variant: String, route: String) -> SfButton:
	var b: SfButton = SfButton.make(key, icon, variant)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if route == "continue":
		b.pressed.connect(func() -> void: go("continue", {"slot": _newest["slot"], "state": _newest["state"]}))
	else:
		b.pressed.connect(go.bind(route))
	into.add_child(b)
	return b


func _version() -> Label:
	var l: Label = FlowScreen.label(Strings.fmt("ui.title.version", {"version": Game.game_version()}), &"CaptionLabel")
	l.name = "Version"
	l.set_meta("audit_numeric_ok", "the build version")
	return l


static func _scenario_name_key(scenario_id: String) -> String:
	return DictIO.str_of(Content.db().scenarios.get(scenario_id, {}), "name_key", "ui.title.unknown_scenario")


## The newest save that loads, so Continue never offers a damaged file.
static func _find_newest() -> Dictionary:
	for s: Dictionary in SaveService.list_slots():
		var lr: SaveSerializer.LoadResult = SaveService.load_slot(str(s["slot"]))
		if lr.ok and lr.state != null:
			return {"slot": str(s["slot"]), "state": lr.state}
	return {}
