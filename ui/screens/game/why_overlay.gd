class_name WhyOverlay
extends RefCounted
## Why? (§6.3): for a colony or an event, what changed at the last turn's end and what caused it,
## from the turn's WhyLog ("Stability fell 58 to 44: unemployed settlers, an expired festival...").


static func open(subject_kind: String, subject_id: String) -> Modal:
	var m: Modal = Modal.make(Strings.fmt("ui.why.title"))
	m.name = "WhyOverlay"
	var entries: Array[WhyLog.Entry] = []
	if Game.last_result != null:
		entries = Game.last_result.why_log.for_subject(subject_kind, subject_id)
	if entries.is_empty():
		m.body.add_child(FlowScreen.label(Strings.fmt("ui.why.nothing"), &"SecondaryLabel"))
	for e: WhyLog.Entry in entries:
		m.body.add_child(_entry(e))
	m.open()
	return m


static func _entry(e: WhyLog.Entry) -> Control:
	var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
	v.name = "WhyEntry"
	v.add_child(FlowScreen.label(Strings.fmt(e.label_key, e.label_args), &"StrongLabel"))
	if e.from_value != e.to_value:
		v.add_child(GameUI.caption(Strings.fmt("ui.why.from_to", {"from": _fmt(e.unit, e.from_value), "to": _fmt(e.unit, e.to_value)})))
	for c: WhyLog.Cause in e.causes:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_S)
		var t: Label = FlowScreen.label(Strings.fmt(c.source_key, c.source_args), &"SecondaryLabel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		var val: Label = Label.new()
		val.theme_type_variation = &"MonoLabel"
		val.text = _fmt(e.unit, c.value)
		val.add_theme_color_override("font_color", Tokens.color(Tokens.POSITIVE if c.value > 0 else Tokens.NEGATIVE))
		row.add_child(val)
		v.add_child(row)
	# The log records what happened, with the numbers it changed.
	return GameUI.panel(GameUI.exempt(v, "the causes of a change, as the turn recorded them"))


static func _fmt(unit: String, v: int) -> String:
	match unit:
		Breakdown.UNIT_CENTI, Breakdown.UNIT_RESOURCE:
			return Fmt.centi(v, true, 2)
		Breakdown.UNIT_PERCENT:
			return Fmt.bp(v)
		Breakdown.UNIT_POINTS:
			return Fmt.points(v)
	return str(v)
