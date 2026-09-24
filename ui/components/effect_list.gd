class_name EffectList
extends VBoxContainer
## Effect records as readable lines, each with an icon that says whether it helps or hurts (so
## colour is never the only signal). Built from EffectText, which the simulation provides.


static func make(state: GameState, effects: Array, colony_id: String = "") -> EffectList:
	var l: EffectList = EffectList.new()
	l.add_theme_constant_override("separation", Tokens.SPACE_XS)
	for line: EffectText.Line in EffectText.describe_all(state, effects, colony_id):
		l.add_child(row(line))
	return l


static func text_of(line: EffectText.Line) -> String:
	var parts: PackedStringArray = PackedStringArray([Strings.fmt(line.key, line.args)])
	if not line.scope_key.is_empty():
		parts.append(Strings.fmt(line.scope_key, line.scope_args))
	if not line.time_key.is_empty():
		parts.append(Strings.fmt(line.time_key, line.time_args))
	var s: String = " ".join(parts)
	return s.substr(0, 1).to_upper() + s.substr(1)


static func row(line: EffectText.Line) -> HBoxContainer:
	var r: HBoxContainer = HBoxContainer.new()
	r.add_theme_constant_override("separation", Tokens.SPACE_S)
	var icon: SfIcon = SfIcon.make("ui_plus" if line.good else "ui_minus", Tokens.ICON_S, Tokens.POSITIVE if line.good else Tokens.NEGATIVE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(icon)
	var t: Label = Label.new()
	t.text = text_of(line)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Effect lines state a promise ("+5 stability for 10 turns"), not a derived number.
	t.set_meta("audit_numeric_ok", true)
	r.add_child(t)
	return r
