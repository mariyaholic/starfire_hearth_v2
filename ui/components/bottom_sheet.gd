class_name BottomSheet
extends OverlayLayer
## The phone's selection panel (§7): a sheet at the bottom that snaps to peek, half or full height.
## Drag the handle to resize; drag it down past the peek height to close.

const SNAPS: Array[float] = [0.36, 0.6, 0.92]
## Pass as the snap to size the sheet to its content (up to the tallest snap).
const FIT: int = -1

var body: VBoxContainer
var snap_index: int = 1
var _title_text: String = ""
var _handle: Control
var _dragging: bool = false
var _drag_start_y: float = 0.0
var _drag_start_h: float = 0.0
var _height: float = 0.0
var _inset: MarginContainer
var _scroll: ScrollContainer


static func make(title_text: String, p_snap: int = 1) -> BottomSheet:
	var s: BottomSheet = BottomSheet.new()
	s._title_text = title_text
	s.snap_index = p_snap if p_snap == FIT else clampi(p_snap, 0, SNAPS.size() - 1)
	s._build()
	return s


func _build() -> void:
	name = "BottomSheet"
	_scrim.color = Color(Tokens.color("bg.deep"), 0.45)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"SheetPanel"
	_inset = MarginContainer.new()
	panel.add_child(_inset)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_S)
	_inset.add_child(col)
	_handle = Control.new()
	_handle.name = "Handle"
	_handle.custom_minimum_size = Vector2(0, Tokens.TOUCH_TARGET_DP * 0.5)
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_handle.draw.connect(_draw_handle)
	_handle.gui_input.connect(_on_handle_input)
	col.add_child(_handle)
	col.add_child(_make_header(_title_text, &"H2Label"))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_S)
	_scroll = OverlayLayer.make_scroll(body)
	col.add_child(_scroll)
	body.minimum_size_changed.connect(_relayout)
	add_child(panel)
	Layout.changed.connect(_relayout)
	resized.connect(_relayout)
	_relayout()


func snap_to(i: int) -> void:
	snap_index = clampi(i, 0, SNAPS.size() - 1)
	_height = -1.0
	_relayout()


func _view() -> Vector2:
	return size if size.x > 0.0 else Layout.logical_size


func _relayout() -> void:
	if panel == null:
		return
	var view: Vector2 = _view()
	var m: Vector4 = Layout.safe_margins
	var h: float = _height
	if h <= 0.0:
		if snap_index == FIT:
			h = OverlayLayer.fit_scroll(panel, _scroll, body, view.y * SNAPS[SNAPS.size() - 1])
		else:
			_scroll.custom_minimum_size.y = 0.0
			h = view.y * SNAPS[snap_index]
	var w: float = view.x - m.x - m.z if Layout.compact else minf(760.0, view.x - 64.0)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -w / 2.0 + (m.x - m.z) / 2.0
	panel.offset_right = w / 2.0 + (m.x - m.z) / 2.0
	panel.offset_top = -h
	panel.offset_bottom = 0.0
	_inset.add_theme_constant_override("margin_bottom", int(m.w))


func _draw_handle() -> void:
	var w: float = 40.0
	var r: Rect2 = Rect2((_handle.size.x - w) / 2.0, _handle.size.y / 2.0 - 2.0, w, 4.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Tokens.color("text.secondary")
	sb.set_corner_radius_all(2)
	_handle.draw_style_box(sb, r)


func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_dragging = true
			_drag_start_y = mb.global_position.y
			_drag_start_h = -panel.offset_top
		else:
			_dragging = false
			_settle()
	elif event is InputEventMouseMotion and _dragging:
		var dy: float = (event as InputEventMouseMotion).global_position.y - _drag_start_y
		_height = clampf(_drag_start_h - dy, 80.0, _view().y * SNAPS[SNAPS.size() - 1])
		_relayout()


func _settle() -> void:
	var view_h: float = _view().y
	var frac: float = _height / view_h if _height > 0.0 else SNAPS[maxi(snap_index, 0)]
	if frac < SNAPS[0] * 0.6:
		_height = -1.0
		dismiss()
		return
	var best: int = 0
	for i in SNAPS.size():
		if absf(SNAPS[i] - frac) < absf(SNAPS[best] - frac):
			best = i
	snap_to(best)


func _animate_in() -> void:
	if Settings.reduce_motion:
		return
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, Tokens.TWEEN_NORMAL).set_ease(Tween.EASE_OUT)
