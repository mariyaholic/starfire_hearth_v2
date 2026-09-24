class_name BreakdownTooltip
extends PanelContainer
## The panel that shows one Breakdown (§6.1): label and total, then each line with its source and
## signed value, then the note and Codex links. Lines that have their own breakdown open it (level
## 2) on hover or tap. Built only from what the simulation emitted.

var breakdown: Breakdown = null
var level: int = 1
var pinned: bool = false:
	set(v):
		pinned = v
		if _close_button != null:
			_close_button.visible = v

var _close_button: SfButton = null
var _scroll: ScrollContainer
var _col: VBoxContainer


func setup(b: Breakdown, p_level: int) -> void:
	breakdown = b
	level = p_level
	theme_type_variation = &"BreakdownPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("breakdown_tooltip")
	# Wider with larger text, so a long value does not squeeze its source to a word per line.
	var width: float = 360.0 * maxf(1.0, Settings.text_scale)
	if Layout.compact:
		width = minf(width, Layout.logical_size.x - 16.0 - Layout.safe_margins.x - Layout.safe_margins.z)
	custom_minimum_size.x = width
	_build()


## Caps the panel at `max_height` (logical px); taller content scrolls inside it.
func fit(max_height: float) -> void:
	var pad: float = 0.0
	var sb: StyleBox = get_theme_stylebox("panel")
	if sb != null:
		pad = sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)
	var want: float = _col.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(want, maxf(80.0, max_height - pad))


func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_XS)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(col)
	_col = col

	# Title and close on one row; the total joins them on PC, and gets its own row when space is
	# tight (phones, large text) so the title never breaks mid-word.
	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var title: Label = Label.new()
	title.theme_type_variation = &"H2Label"
	title.text = Strings.fmt(breakdown.label_key, breakdown.label_args)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var total: Label = _value_label(Fmt.total(breakdown) + _unit_suffix(), breakdown.total, true)
	total.theme_type_variation = &"MonoStrongLabel"
	var stacked: bool = Layout.compact or Settings.text_scale > 1.25
	if not stacked:
		head.add_child(total)
	_close_button = SfButton.make_icon("ui_close", "ui.tooltip.close")
	_close_button.visible = pinned
	_close_button.pressed.connect(func() -> void: Overlay.close_breakdowns(level))
	head.add_child(_close_button)
	if stacked:
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(total)

	col.add_child(HSeparator.new())
	for line: Breakdown.Line in breakdown.visible_lines():
		col.add_child(_line_row(line))
	col.add_child(HSeparator.new())
	var total_row: HBoxContainer = HBoxContainer.new()
	var tl: Label = Label.new()
	tl.theme_type_variation = &"StrongLabel"
	tl.text = Strings.fmt("ui.breakdown.total")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(tl)
	total_row.add_child(_value_label(Fmt.total(breakdown) + Fmt.suffix(breakdown, false), breakdown.total, true))
	col.add_child(total_row)

	if not breakdown.note_key.is_empty():
		var note: Label = Label.new()
		note.theme_type_variation = &"CaptionLabel"
		note.text = Strings.fmt(breakdown.note_key, breakdown.note_args)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(note)
	if not breakdown.links.is_empty():
		var links: HFlowContainer = HFlowContainer.new()
		for id: String in breakdown.links:
			var b: SfButton = SfButton.make("ui.breakdown.codex_link", "ui_codex", SfButton.LINK)
			b.set_meta("codex_id", id)
			links.add_child(b)
		col.add_child(links)
	if level == 1 and _has_children():
		var hint: Label = Label.new()
		hint.theme_type_variation = &"CaptionLabel"
		hint.text = Strings.fmt("ui.breakdown.hint_touch" if Layout.touch_ui else "ui.breakdown.hint_pointer")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hint)


func _line_row(line: Breakdown.Line) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	var src: Label = Label.new()
	src.text = _source_text(line)
	if line.kind == Breakdown.KIND_BASE:
		src.theme_type_variation = &"StrongLabel"
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(src)
	var val_text: String = Fmt.line_value(breakdown, line.value)
	if line.kind == Breakdown.KIND_MULT:
		val_text = "%s (%s)" % [Fmt.bp(line.bp), val_text]
	row.add_child(_value_label(val_text, line.value, false))
	if line.child != null and level < Overlay.MAX_LEVELS:
		var chev: SfIcon = SfIcon.make("ui_chevron_right", Tokens.ICON_S, "text.secondary")
		row.add_child(chev)
		var e: Explainable = Explainable.wrap(row, line.child, true)
		e.level = level + 1
		return e
	return row


func _source_text(line: Breakdown.Line) -> String:
	if line.kind == Breakdown.KIND_CAP:
		var cap_key: String = "ui.breakdown.cap_max" if line.cap_dir == "max" else "ui.breakdown.cap_min"
		return Strings.fmt(cap_key, {"limit": Fmt.total(_cap_proxy(line.limit)), "source_key": line.source_key})
	return Strings.fmt(line.source_key, line.source_args)


func _cap_proxy(v: int) -> Breakdown:
	var b: Breakdown = Breakdown.make("", breakdown.unit)
	b.total = v
	return b


func _value_label(text: String, value: int, strong: bool) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = &"MonoStrongLabel" if strong else &"MonoLabel"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if value > 0:
		l.add_theme_color_override("font_color", Tokens.color(Tokens.POSITIVE))
	elif value < 0:
		l.add_theme_color_override("font_color", Tokens.color(Tokens.NEGATIVE))
	return l


func _unit_suffix() -> String:
	return Fmt.suffix(breakdown)


func _has_children() -> bool:
	for l: Breakdown.Line in breakdown.lines:
		if l.child != null:
			return true
	return false

