class_name DebriefScreen
extends FlowScreen
## The debrief (§7 screen 15, §10.1, §5.12): the outcome and why, the objectives as they ended, and
## after a win the legacy pick (1 of the scenario's 3) that carries into the later scenarios.
## Continue returns to the campaign once a legacy is picked. After a loss, Try again opens the
## briefing for a fresh start (the checkpoint reload arrives with the save rings).

var progress: CampaignProgress
var state: GameState
## The legacy picked on this screen (a replayed win starts from the earlier pick).
var picked: String = ""
var _continue: SfButton
var _pick_hint: Label
var _legacy_cards: Dictionary[String, Card] = {}
var _legacy_buttons: Dictionary[String, SfButton] = {}


static func make(p_progress: CampaignProgress, p_state: GameState) -> DebriefScreen:
	var s: DebriefScreen = DebriefScreen.new()
	s.name = "DebriefScreen"
	s.progress = p_progress
	s.state = p_state
	if p_state != null:
		s.picked = p_progress.legacy_of(p_state.scenario_id)
	return s


func won() -> bool:
	return state != null and state.outcome == GameState.OUTCOME_WON


## The scenario's legacy ids (none for scenarios without a pick).
func legacies() -> Array[String]:
	var out: Array[String] = []
	if state == null:
		return out
	for v: Variant in DictIO.arr_of(Content.db().scenarios.get(state.scenario_id, {}), "legacies"):
		if Content.db().has("legacies", str(v)):
			out.append(str(v))
	return out


func build_screen() -> void:
	var rec: Dictionary = Content.db().scenarios.get(state.scenario_id, {}) if state != null else {}
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	_continue = null
	_pick_hint = null
	var actions: Array[Control] = _actions()
	# Phones put the buttons in the heading row, leaving the rest of the short screen to the text.
	var in_header: Array[Control] = []
	if Layout.compact:
		in_header = actions
	col.add_child(header(Strings.fmt("ui.debrief.won" if won() else "ui.debrief.lost"), Strings.fmt(DictIO.str_of(rec, "name_key", "ui.title.unknown_scenario")), in_header))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", Tokens.SPACE_L)
	var top: BoxContainer = _box(Layout.compact)
	top.add_theme_constant_override("separation", Tokens.SPACE_L)
	var outcome: Card = _outcome_card(rec)
	var goals: Card = _objectives_card()
	if not Layout.compact:
		outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outcome.size_flags_stretch_ratio = 1.4
		goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(outcome)
	top.add_child(goals)
	body.add_child(top)
	if won() and not legacies().is_empty():
		body.add_child(_legacy_section())
	col.add_child(FlowScreen.scroll_of(body))
	if not Layout.compact:
		var footer: HFlowContainer = HFlowContainer.new()
		footer.name = "Footer"
		footer.alignment = FlowContainer.ALIGNMENT_END
		footer.add_theme_constant_override("h_separation", Tokens.SPACE_M)
		if won():
			_pick_hint = FlowScreen.label(Strings.fmt("ui.debrief.pick_first"), &"CaptionLabel")
			_pick_hint.name = "PickHint"
			_pick_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_pick_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
			footer.add_child(_pick_hint)
		for a: Control in actions:
			footer.add_child(a)
		col.add_child(footer)
	_refresh_legacies()


func _outcome_card(rec: Dictionary) -> Card:
	var c: Card = Card.make("")
	c.name = "Outcome"
	var who: HBoxContainer = HBoxContainer.new()
	who.add_theme_constant_override("separation", Tokens.SPACE_M)
	who.add_child(Portrait.make(BriefingScreen.ADVISOR, "warm" if won() else "worried", 64.0 if Layout.compact else 96.0))
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var reason: Label = FlowScreen.label(Strings.fmt(state.outcome_reason if state != null and not state.outcome_reason.is_empty() else "ui.debrief.no_reason"), &"StrongLabel")
	reason.name = "Reason"
	texts.add_child(reason)
	if state != null:
		var when: Label = FlowScreen.label(Strings.fmt("ui.debrief.when", {"date": Fmt.date(state.outcome_turn), "turn": state.outcome_turn}), &"CaptionLabel")
		when.name = "When"
		when.set_meta("audit_numeric_ok", "the date and turn the scenario ended")
		texts.add_child(when)
	who.add_child(texts)
	c.add_body(who)
	var story: Label = c.add_text(Strings.fmt(DictIO.str_of(rec, "debrief_key", "ui.debrief.won_body") if won() else "ui.debrief.lost_body"))
	story.name = "Story"
	story.set_meta("audit_numeric_ok", "story prose")
	return c


func _objectives_card() -> Card:
	var c: Card = Card.make(Strings.fmt("ui.debrief.objectives"), "", "ui_objective", "hearth.gold")
	c.name = "Objectives"
	if state == null:
		return c
	var shown_optional: bool = false
	for s: Objectives.Status in Objectives.statuses(state):
		if not s.required and not shown_optional:
			shown_optional = true
			c.add_body(FlowScreen.label(Strings.fmt("ui.briefing.optional"), &"StrongLabel"))
		var icon: String = "ui_check" if s.done else "ui_close"
		var token: String = "ok.green" if s.done else ("alert.ember" if s.failed else "text.secondary")
		var row: HBoxContainer = BriefingScreen.objective_row(Strings.fmt(s.text_key), icon, token)
		row.name = "Objective_" + s.id
		c.add_body(row)
	return c


func _legacy_section() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Legacies"
	v.add_theme_constant_override("separation", Tokens.SPACE_S)
	v.add_child(FlowScreen.label(Strings.fmt("ui.debrief.legacy_title"), &"H2Label"))
	v.add_child(FlowScreen.label(Strings.fmt("ui.debrief.legacy_hint"), &"SecondaryLabel"))
	_legacy_cards.clear()
	_legacy_buttons.clear()
	var row: BoxContainer = _box(Layout.compact)
	row.add_theme_constant_override("separation", Tokens.SPACE_L)
	var group: ButtonGroup = ButtonGroup.new()
	var db: ContentDb = Content.db()
	for id: String in legacies():
		var rec: Dictionary = db.record("legacies", id)
		var c: Card = Card.make(Strings.fmt(DictIO.str_of(rec, "name_key")), "", DictIO.str_of(rec, "icon", "ui_legacy"), "hearth.gold")
		c.name = "Legacy_" + id
		if not Layout.compact:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var desc: Label = c.add_text(Strings.fmt(DictIO.str_of(rec, "desc_key")), &"SecondaryLabel")
		desc.set_meta("audit_numeric_ok", "a legacy's promised effect, stated in words")
		var b: SfButton = SfButton.make("ui.debrief.legacy_pick", "ui_legacy", SfButton.TAB)
		b.name = "Pick"
		b.button_group = group
		b.button_pressed = id == picked
		b.pressed.connect(pick.bind(id))
		c.add_action(b)
		row.add_child(c)
		_legacy_cards[id] = c
		_legacy_buttons[id] = b
	v.add_child(row)
	return v


## A column on phones, a row on PC.
static func _box(vertical: bool) -> BoxContainer:
	if vertical:
		return VBoxContainer.new()
	return HBoxContainer.new()


## Chooses the legacy to carry forward (Continue records it).
func pick(legacy_id: String) -> void:
	picked = legacy_id
	_refresh_legacies()


func needs_pick() -> bool:
	return won() and not legacies().is_empty() and picked.is_empty()


## The screen's buttons: Continue after a win; Campaign and Try again after a loss.
func _actions() -> Array[Control]:
	var out: Array[Control] = []
	if won():
		_continue = SfButton.make("ui.debrief.continue", "ui_chevron_right", SfButton.PRIMARY)
		_continue.name = "Continue"
		_continue.pressed.connect(_finish)
		out.append(_continue)
		return out
	var camp: SfButton = SfButton.make("ui.debrief.to_campaign", "ui_back", SfButton.SECONDARY)
	camp.name = "ToCampaign"
	camp.pressed.connect(go.bind(AppRoot.CAMPAIGN))
	out.append(camp)
	var retry: SfButton = SfButton.make("ui.debrief.retry", "ui_reroll", SfButton.PRIMARY)
	retry.name = "Retry"
	retry.pressed.connect(go.bind(AppRoot.BRIEFING, {"scenario": state.scenario_id if state != null else ""}))
	out.append(retry)
	return out


## Shows the pick in place (no rebuild, so a phone keeps its scroll position): the chosen card is
## outlined in gold and its button says so; Continue waits until something is chosen.
func _refresh_legacies() -> void:
	for id: String in _legacy_cards.keys():
		var chosen: bool = id == picked
		var b: SfButton = _legacy_buttons[id]
		b.text = Strings.fmt("ui.debrief.legacy_chosen" if chosen else "ui.debrief.legacy_pick")
		b.set_icon_id("ui_check" if chosen else "ui_legacy")
		b.set_pressed_no_signal(chosen)
		var card: Card = _legacy_cards[id]
		if chosen:
			var base: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
			var box: StyleBoxFlat = base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
			box.set_border_width_all(2)
			box.border_color = Tokens.color("hearth.gold")
			card.add_theme_stylebox_override("panel", box)
		else:
			card.remove_theme_stylebox_override("panel")
	if _continue != null:
		_continue.disabled = needs_pick()
		_continue.tooltip_text = Strings.fmt("ui.debrief.pick_first") if needs_pick() else ""
	if _pick_hint != null:
		_pick_hint.visible = needs_pick()


func _finish() -> void:
	if needs_pick():
		return
	if won() and not picked.is_empty():
		progress.pick_legacy(state.scenario_id, picked)
	go(AppRoot.CAMPAIGN)


func demo(state_name: String) -> void:
	if state_name.begins_with("pick:"):
		pick(state_name.trim_prefix("pick:"))
	await get_tree().process_frame
