class_name TopBar
extends PanelContainer
## The top bar (§7): the six resources (stock, net per turn, breakdown), the Noise waveform, the
## turn and date, and the menu. On compact layouts it shows food, energy, minerals and alloys, and a
## "more" button opens a drawer with the rest.

signal menu_pressed

const COMPACT_RESOURCES: Array[String] = ["food", "energy", "minerals", "alloys"]


## Everything the bar shows. Filled by the screen from the simulation (or sample data).
class Model:
	extends RefCounted
	## resource id -> {icon, color, stock (centi, -1 for none), net (centi), breakdown}
	var resources: Dictionary[String, Dictionary] = {}
	var resource_order: Array[String] = []
	## Noise in centi-units, 0..10000.
	var noise: int = 0
	var noise_breakdown: Breakdown = null
	var turn: int = 1
	var turn_breakdown: Breakdown = null


var model: Model = null
var _row: HBoxContainer
var _inset: MarginContainer


func _init() -> void:
	theme_type_variation = &"BarPanel"
	name = "TopBar"
	_inset = MarginContainer.new()
	add_child(_inset)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", Tokens.SPACE_S)
	_inset.add_child(_row)


func _ready() -> void:
	Layout.changed.connect(_rebuild)


func set_model(m: Model) -> void:
	model = m
	_rebuild()


func _rebuild() -> void:
	if model == null or _row == null:
		return
	for c: Node in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	var m: Vector4 = Layout.safe_margins
	_inset.add_theme_constant_override("margin_left", int(m.x))
	_inset.add_theme_constant_override("margin_right", int(m.z))
	var compact: bool = Layout.compact
	# Resources sit in a strip that takes the width left over and can be swiped when it overflows
	# (phones at large text sizes), so the bar never pushes the screen wider.
	var strip: ScrollContainer = ScrollContainer.new()
	strip.name = "ResourceStrip"
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(strip)
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", Tokens.SPACE_S)
	strip.add_child(chips)
	var shown: Array[String] = COMPACT_RESOURCES if compact else model.resource_order
	for rid: String in shown:
		if model.resources.has(rid):
			chips.add_child(_chip(rid))
	if compact:
		var more: SfButton = SfButton.make("ui.topbar.more", "ui_plus", SfButton.GHOST)
		more.name = "More"
		more.pressed.connect(open_more)
		_row.add_child(more)
	else:
		chips.add_child(_noise_block())
		_row.add_child(_date_block())
	var menu: SfButton = SfButton.make_icon("ui_menu", "ui.topbar.menu")
	menu.name = "Menu"
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	_row.add_child(menu)


func _chip(rid: String) -> ResourceChip:
	var r: Dictionary = model.resources[rid]
	var chip: ResourceChip = ResourceChip.make_chip(rid, r["icon"], r["color"], int(r["stock"]), int(r["net"]), r["breakdown"])
	chip.name = "Chip_" + rid.capitalize()
	if int(r["stock"]) < 0:
		chip.hide_stock()
	return chip


func _noise_block() -> Explainable:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_XS)
	row.add_child(SfIcon.make("stat_noise", Tokens.ICON_M, "sci.cyan"))
	var wave: NoiseWave = NoiseWave.new()
	wave.noise = model.noise / 100.0
	row.add_child(wave)
	var v: Label = Label.new()
	v.theme_type_variation = &"MonoStrongLabel"
	v.text = Fmt.centi(model.noise, false, 1)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	var e: Explainable = Explainable.wrap(row, model.noise_breakdown)
	e.name = "NoiseMeter"
	e.custom_minimum_size.y = Layout.target_size()
	return e


func _date_block() -> Explainable:
	var l: Label = Label.new()
	l.theme_type_variation = &"StrongLabel"
	l.text = Fmt.date(model.turn)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var e: Explainable = Explainable.wrap(l, model.turn_breakdown)
	e.name = "Date"
	e.custom_minimum_size.y = Layout.target_size()
	return e


func open_more() -> void:
	var d: Drawer = Drawer.make(Strings.fmt("ui.topbar.more_title"), Drawer.SIDE_RIGHT)
	d.name = "MoreDrawer"
	for rid: String in model.resource_order:
		if not model.resources.has(rid):
			continue
		var label: String = Strings.fmt(str(model.resources[rid].get("name_key", "")))
		var u: String = Fmt.unit(rid)
		if not u.is_empty():
			label = Strings.fmt("ui.fmt.name_unit", {"name": label, "unit": u})
		d.body.add_child(_labelled(label, _chip(rid)))
	d.body.add_child(_labelled(Strings.fmt("ui.topbar.noise"), _noise_block()))
	d.body.add_child(_labelled(Strings.fmt("ui.topbar.date"), _date_block()))
	d.open()


func _labelled(text: String, c: Control) -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = &"SecondaryLabel"
	l.custom_minimum_size.x = 120.0 * Settings.text_scale
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(c)
	return row
