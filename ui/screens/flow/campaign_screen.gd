class_name CampaignScreen
extends FlowScreen
## Campaign select (§7 screen 2, §10.1): the difficulty preset with its description, then the three
## scenario cards in order (a row on PC; a row that scrolls sideways on phones). A card gives the
## synopsis and the scenario's state: ready, won (with the legacy picked), locked until the one
## before is won, or not in this build yet. Play (or Replay) opens the briefing.

var progress: CampaignProgress
var _difficulty_desc: Label


static func make(p_progress: CampaignProgress) -> CampaignScreen:
	var s: CampaignScreen = CampaignScreen.new()
	s.name = "CampaignScreen"
	s.progress = p_progress
	s.back_route = AppRoot.TITLE
	return s


func build_screen() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	col.add_child(header(Strings.fmt("ui.campaign.title")))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", Tokens.SPACE_XL)
	body.add_child(FlowScreen.label(Strings.fmt("ui.campaign.intro"), &"SecondaryLabel"))
	body.add_child(_difficulty())
	body.add_child(_scenarios())
	col.add_child(FlowScreen.scroll_of(body))


func _difficulty() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Difficulty"
	v.add_theme_constant_override("separation", Tokens.SPACE_S)
	v.add_child(FlowScreen.label(Strings.fmt("ui.campaign.difficulty"), &"H2Label"))
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	row.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	var group: ButtonGroup = ButtonGroup.new()
	var db: ContentDb = Content.db()
	for id: String in db.ids("difficulty"):
		var b: SfButton = SfButton.make(DictIO.str_of(db.record("difficulty", id), "name_key"), "", SfButton.TAB)
		b.name = "Difficulty_" + id
		b.button_group = group
		b.button_pressed = id == progress.difficulty_id
		b.pressed.connect(_pick_difficulty.bind(id))
		row.add_child(b)
	v.add_child(row)
	_difficulty_desc = FlowScreen.label(_difficulty_text(), &"SecondaryLabel")
	_difficulty_desc.name = "DifficultyDesc"
	v.add_child(_difficulty_desc)
	return v


func _difficulty_text() -> String:
	return Strings.fmt(DictIO.str_of(Content.db().record("difficulty", progress.difficulty_id), "desc_key", "difficulty.normal.desc"))


func _pick_difficulty(id: String) -> void:
	if progress.difficulty_id == id:
		return
	progress.difficulty_id = id
	# In place, so a phone keeps its scroll position.
	if _difficulty_desc != null:
		_difficulty_desc.text = _difficulty_text()


func _scenarios() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Scenarios"
	row.add_theme_constant_override("separation", Tokens.SPACE_L)
	var card_w: float = clampf(Layout.logical_size.x * 0.62, 280.0, 520.0)
	for id: String in CampaignProgress.ORDER:
		var c: Card = _card(id)
		if Layout.compact:
			c.custom_minimum_size.x = card_w
		else:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
	if not Layout.compact:
		return row
	# Phones: the cards sit in a row wider than the screen, swiped sideways.
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = "ScenarioScroll"
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(row)
	return sc


func _card(id: String) -> Card:
	var db: ContentDb = Content.db()
	var rec: Dictionary = db.scenarios.get(id, {})
	var playable: bool = DictIO.str_of(rec, "status") == "playable"
	var unlocked: bool = progress.is_unlocked(id)
	var state_text: String
	var icon: String
	var token: String
	if progress.is_won(id):
		var legacy: String = progress.legacy_of(id)
		if legacy.is_empty():
			state_text = Strings.fmt("ui.campaign.state.won")
		else:
			state_text = Strings.fmt("ui.campaign.state.won_legacy", {"legacy_key": DictIO.str_of(db.record("legacies", legacy), "name_key")})
		icon = "ui_check"
		token = "ok.green"
	elif not unlocked:
		var prev: Dictionary = db.scenarios.get(progress.previous_of(id), {})
		state_text = Strings.fmt("ui.campaign.state.locked", {"previous_key": DictIO.str_of(prev, "name_key")})
		icon = "ui_lock"
		token = "text.secondary"
	elif not playable:
		state_text = Strings.fmt("ui.campaign.state.later")
		icon = "ui_lock"
		token = "text.secondary"
	else:
		state_text = Strings.fmt("ui.campaign.state.ready")
		icon = "ui_play"
		token = "accent.teal"
	var c: Card = Card.make(Strings.fmt(DictIO.str_of(rec, "name_key")), state_text, icon, token)
	c.name = "Scenario_" + id
	var synopsis: Label = c.add_text(Strings.fmt(DictIO.str_of(rec, "desc_key")), &"SecondaryLabel")
	synopsis.set_meta("audit_numeric_ok", "story prose (the in-world year)")
	if unlocked and playable:
		var b: SfButton = SfButton.make("ui.campaign.replay" if progress.is_won(id) else "ui.campaign.play", "ui_play", SfButton.SECONDARY if progress.is_won(id) else SfButton.PRIMARY)
		b.name = "Play"
		b.pressed.connect(go.bind(AppRoot.BRIEFING, {"scenario": id}))
		c.add_action(b)
	return c
