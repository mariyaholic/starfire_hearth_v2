class_name ObjectivesView
extends RefCounted
## The objectives (§5.12, §7): what wins the scenario, how far each one is, and the optional ones.


static func build(s: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var scenario: Dictionary = Content.db().scenarios.get(s.state.scenario_id, {})
	var card: Card = Card.make(Strings.fmt(DictIO.str_of(scenario, "name_key")), Strings.fmt("ui.objectives.subtitle"), "ui_objective", "hearth.gold")
	card.name = "Objectives"
	var optional: Array[Objectives.Status] = []
	card.add_body(GameUI.heading(Strings.fmt("ui.objectives.required")))
	for st: Objectives.Status in Objectives.statuses(s.state):
		if st.required:
			card.add_body(_row(st))
		else:
			optional.append(st)
	if not optional.is_empty():
		card.add_body(GameUI.heading(Strings.fmt("ui.objectives.optional")))
		for st: Objectives.Status in optional:
			card.add_body(_row(st))
	col.add_child(card)
	var decode: Control = _decode(s)
	if decode != null:
		col.add_child(decode)
	return col


static func _row(st: Objectives.Status) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Objective_" + st.id
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	var icon: String = "ui_check" if st.done else ("alert_warning" if st.failed else "ui_objective")
	var token: String = "ok.green" if st.done else (Tokens.NEGATIVE if st.failed else "text.secondary")
	var mark: SfIcon = SfIcon.make(icon, Tokens.ICON_M, token)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var text: Label = FlowScreen.label(Strings.fmt(st.text_key))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The objective's own wording, which quotes its targets.
	text.set_meta("audit_numeric_ok", "the objective's own text")
	row.add_child(text)
	if st.target > 1:
		var count: Label = Label.new()
		count.theme_type_variation = &"MonoLabel"
		count.text = "%d / %d" % [mini(st.progress, st.target), st.target]
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(GameUI.exempt(count, "progress towards the objective's target"))
		var m: Meter = Meter.make(float(mini(st.progress, st.target)), float(st.target), "ok.green" if st.done else "accent.teal")
		m.custom_minimum_size.x = 96.0
		row.add_child(m)
	return row


## The Sealed Order's decoding, once the Archive is working on it.
static func _decode(s: GameScreen) -> Control:
	if not s.state.flags.has("sealed_order_active"):
		return null
	var e: Empire = s.state.player()
	var trigger: Dictionary = DictIO.dict_of(Events.step_of("sealed_order", 2), "trigger")
	var target: int = DictIO.int_of(trigger, "decode_min", 1000)
	var card: Card = Card.make(Strings.fmt("ui.objectives.decode"), Strings.fmt("ui.objectives.decode_note"), "ui_codex", "sci.cyan")
	card.name = "Decoding"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	var m: Meter = Meter.make(float(mini(e.decode_progress, target)), float(target), "sci.cyan")
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(m)
	var b: Breakdown = s.report.decode
	var v: Label = Label.new()
	v.theme_type_variation = &"MonoLabel"
	v.text = Strings.fmt("ui.fmt.rate", {"value": Fmt.centi(b.total), "resource": Strings.fmt("res.research.name")})
	row.add_child(Explainable.wrap(v, b))
	card.add_body(row)
	return card
