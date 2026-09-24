class_name Drawer
extends OverlayLayer
## A panel that slides in from the left (the outliner on phones) or the right (the "more" drawer of
## the top bar). Tap the scrim or press back to close.

const SIDE_LEFT: int = 0
const SIDE_RIGHT: int = 1

var body: VBoxContainer
var side: int = SIDE_LEFT
var _title_text: String = ""
var _inset: MarginContainer


static func make(title_text: String, p_side: int = SIDE_LEFT) -> Drawer:
	var d: Drawer = Drawer.new()
	d._title_text = title_text
	d.side = p_side
	d._build()
	return d


func _build() -> void:
	name = "Drawer"
	panel = PanelContainer.new()
	panel.theme_type_variation = &"DrawerPanel"
	_inset = MarginContainer.new()
	panel.add_child(_inset)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_M)
	_inset.add_child(col)
	col.add_child(_make_header(_title_text, &"H2Label"))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_S)
	col.add_child(OverlayLayer.make_scroll(body))
	add_child(panel)
	Layout.changed.connect(_relayout)
	resized.connect(_relayout)
	_relayout()


func _relayout() -> void:
	if panel == null:
		return
	var m: Vector4 = Layout.safe_margins
	var view: Vector2 = size if size.x > 0.0 else Layout.logical_size
	var w: float = minf(400.0, view.x * 0.86)
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	_inset.add_theme_constant_override("margin_top", int(m.y))
	_inset.add_theme_constant_override("margin_bottom", int(m.w))
	if side == SIDE_LEFT:
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
		panel.offset_left = 0.0
		panel.offset_right = w + m.x
		_inset.add_theme_constant_override("margin_left", int(m.x))
		_inset.add_theme_constant_override("margin_right", 0)
	else:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.offset_left = -w - m.z
		panel.offset_right = 0.0
		_inset.add_theme_constant_override("margin_left", 0)
		_inset.add_theme_constant_override("margin_right", int(m.z))


func _animate_in() -> void:
	if Settings.reduce_motion:
		return
	var dx: float = -40.0 if side == SIDE_LEFT else 40.0
	modulate.a = 0.0
	panel.position.x += dx
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, Tokens.TWEEN_NORMAL).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:x", panel.position.x - dx, Tokens.TWEEN_SLOW).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
