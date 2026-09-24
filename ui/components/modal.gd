class_name Modal
extends OverlayLayer
## A centred card on PC and a full-screen card on phones (§7). Title, scrolling body, and a footer
## of actions. Blocking modals (dismissable = false) have no close button and ignore the scrim.

var body: VBoxContainer
var footer: HFlowContainer
var _title_text: String = ""
var _scroll: ScrollContainer


static func make(title_text: String, p_dismissable: bool = true) -> Modal:
	var m: Modal = Modal.new()
	m._title_text = title_text
	m.dismissable = p_dismissable
	m._build()
	return m


func add_action(b: Control) -> Control:
	footer.add_child(b)
	return b


func _build() -> void:
	name = "Modal"
	panel = PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_M)
	panel.add_child(col)
	col.add_child(_make_header(_title_text))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_M)
	_scroll = OverlayLayer.make_scroll(body)
	col.add_child(_scroll)
	body.minimum_size_changed.connect(_relayout)
	footer = HFlowContainer.new()
	footer.alignment = FlowContainer.ALIGNMENT_END
	col.add_child(footer)
	add_child(panel)
	Layout.changed.connect(_relayout)
	resized.connect(_relayout)
	_relayout()


func _relayout() -> void:
	if panel == null:
		return
	var m: Vector4 = Layout.safe_margins
	if Layout.compact:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = m.x
		panel.offset_top = m.y
		panel.offset_right = -m.z
		panel.offset_bottom = -m.w
		_scroll.custom_minimum_size.y = 0.0
	else:
		# PC: as tall as the content needs, up to 85% of the window; beyond that the body scrolls.
		var view: Vector2 = size if size.x > 0.0 else Layout.logical_size
		var w: float = clampf(view.x * 0.5, 520.0, 720.0)
		panel.custom_minimum_size = Vector2(w, 0)
		var h: float = OverlayLayer.fit_scroll(panel, _scroll, body, view.y * 0.85)
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -w / 2.0
		panel.offset_right = w / 2.0
		panel.offset_top = -h / 2.0
		panel.offset_bottom = h / 2.0
