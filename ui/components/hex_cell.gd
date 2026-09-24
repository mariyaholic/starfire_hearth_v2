class_name HexCell
extends Control
## One slot of the colony planner (§8.3): a flat pointy-top hex with a centred icon and tier pips.
## States: empty, blocked (hatched, with a lock), built, building (progress arc), ghost (dashed
## outline with adjacency chips such as "+10%" or "−2"), and selected (gold outline).
## Colour always comes with an icon or a shape, never alone.

signal pressed

const STATE_EMPTY: String = "empty"
const STATE_BLOCKED: String = "blocked"
const STATE_BUILT: String = "built"
const STATE_BUILDING: String = "building"
const STATE_GHOST: String = "ghost"

## District id -> colour token. Buildings use accent.teal.
const DISTRICT_COLORS: Dictionary[String, String] = {
	"habitation": "accent.teal", "agriculture": "ok.green", "energy": "energy.yellow",
	"mining": "mineral.slate", "industry": "alloy.copper", "research": "sci.cyan",
}

var state: String = STATE_EMPTY:
	set(v):
		state = v
		queue_redraw()
var icon_id: String = "":
	set(v):
		icon_id = v
		queue_redraw()
var color_token: String = "text.secondary":
	set(v):
		color_token = v
		queue_redraw()
var tier: int = 0:
	set(v):
		tier = v
		queue_redraw()
## 0..100, for STATE_BUILDING.
var progress: int = 0:
	set(v):
		progress = v
		queue_redraw()
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
## Adjacency preview chips: [{"text": "+10%", "positive": true}, ...]. They are drawn in a band
## above the hex that is part of this control, so they never cover neighbouring content.
var deltas: Array[Dictionary] = []:
	set(v):
		deltas = v
		_update_size()
## Distance from centre to a corner, in logical pixels.
var radius: float = 34.0:
	set(v):
		radius = v
		_update_size()


static func cell_size(r: float) -> Vector2:
	return Vector2(sqrt(3.0) * r, 2.0 * r)


static func for_district(district_id: String, icon: String, p_tier: int = 1, p_state: String = STATE_BUILT) -> HexCell:
	var h: HexCell = HexCell.new()
	h.state = p_state
	h.icon_id = icon
	h.color_token = DISTRICT_COLORS.get(district_id, "accent.teal")
	h.tier = p_tier
	return h


func _init() -> void:
	custom_minimum_size = cell_size(radius)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	add_to_group("hex_cell")


func _ready() -> void:
	Layout.changed.connect(_update_size)
	_update_size()


func _update_size() -> void:
	custom_minimum_size = cell_size(radius) + Vector2(0, _chip_band())
	queue_redraw()


## Height reserved above the hex for adjacency chips (0 without chips).
func _chip_band() -> float:
	if deltas.is_empty() or not is_inside_tree():
		return 0.0
	return get_theme_font_size("font_size", &"MonoCaptionLabel") * 1.8


## Centre of the hex inside this control.
func hex_center() -> Vector2:
	return Vector2(size.x / 2.0, _chip_band() + radius)


func corners(inset: float = 0.0) -> PackedVector2Array:
	var c: Vector2 = hex_center()
	var r: float = radius - inset
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 6:
		var a: float = deg_to_rad(60.0 * i - 90.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, corners())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			pressed.emit()
			accept_event()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	var outer: PackedVector2Array = corners(1.0)
	var inner: PackedVector2Array = corners(3.0)
	var accent: Color = Tokens.color(color_token)
	var panel: Color = Tokens.color("bg.panel")
	var hc: bool = Tokens.high_contrast
	match state:
		STATE_EMPTY:
			draw_colored_polygon(outer, Tokens.color("bg.panel.alt"))
			_outline(outer, Tokens.color("line.subtle"), 1.0 if not hc else 2.0)
		STATE_BLOCKED:
			draw_colored_polygon(outer, Tokens.color("bg.deep"))
			_hatch(outer, Tokens.color("line.subtle"))
			_outline(outer, Tokens.color("line.subtle"), 1.0 if not hc else 2.0)
			_icon("ui_lock", radius * 0.62, Tokens.color("text.secondary"))
		STATE_BUILT, STATE_BUILDING:
			draw_colored_polygon(outer, panel.lerp(accent, 0.28))
			if state == STATE_BUILDING:
				_dashed(inner, accent, 2.0)
				var c: Vector2 = hex_center()
				draw_arc(c, radius * 0.5, -PI / 2.0, -PI / 2.0 + TAU * progress / 100.0, 32, accent, 3.0, true)
				_icon(icon_id, radius * 0.5, Color(accent, 0.75))
			else:
				_outline(inner, accent, 2.0)
				_icon(icon_id, radius * 0.72, accent)
			_pips()
		STATE_GHOST:
			draw_colored_polygon(outer, Color(accent, 0.12))
			_dashed(inner, accent, 2.0)
			_icon(icon_id, radius * 0.66, Color(accent, 0.8))
	if selected or has_focus():
		_outline(corners(-1.5), Tokens.color("hearth.gold"), 3.0)
	_chips()


func _outline(pts: PackedVector2Array, c: Color, w: float) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, c, w, true)


func _dashed(pts: PackedVector2Array, c: Color, w: float) -> void:
	for i in 6:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 6]
		var n: int = 4
		for k in n:
			var t0: float = float(k) / n
			var t1: float = t0 + 0.55 / n
			draw_line(a.lerp(b, t0 + 0.2 / n), a.lerp(b, t1 + 0.2 / n), c, w, true)


func _hatch(pts: PackedVector2Array, c: Color) -> void:
	var step: float = maxf(6.0, radius / 4.0)
	var r: float = radius
	var cc: Vector2 = hex_center()
	var x: float = -2.0 * r
	while x < 2.0 * r:
		var a: Vector2 = cc + Vector2(x, -r)
		var b: Vector2 = cc + Vector2(x + 2.0 * r, r)
		for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), pts):
			if seg.size() >= 2:
				draw_line(seg[0], seg[seg.size() - 1], Color(c, 0.8), 1.0, true)
		x += step


func _icon(id: String, px_logical: float, c: Color) -> void:
	if id.is_empty():
		return
	var s: float = absf(get_global_transform_with_canvas().get_scale().x) * Layout.scale
	var tex: Texture2D = IconCache.texture(id, ceili(px_logical * maxf(s, 1.0)))
	if tex == null:
		return
	var box: Vector2 = Vector2(px_logical, px_logical)
	draw_texture_rect(tex, Rect2(hex_center() - box / 2.0 - Vector2(0, radius * 0.06), box), false, c)


func _pips() -> void:
	if tier <= 1:
		return
	var c: Vector2 = hex_center() + Vector2(0, radius * 0.62)
	var gap: float = 7.0
	for i in tier:
		var x: float = (i - (tier - 1) / 2.0) * gap
		draw_circle(c + Vector2(x, 0), 2.5, Tokens.color("hearth.gold"), true, -1.0, true)


func _chips() -> void:
	if deltas.is_empty():
		return
	var font: Font = get_theme_font("font", &"MonoCaptionLabel")
	var fsize: int = get_theme_font_size("font_size", &"MonoCaptionLabel")
	var y: float = _chip_band() * 0.45
	var x: float = size.x / 2.0
	var widths: Array[float] = []
	var total: float = 0.0
	for d: Dictionary in deltas:
		var w: float = font.get_string_size(str(d["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 10.0
		widths.append(w)
		total += w + 4.0
	x -= total / 2.0
	for i in deltas.size():
		var d: Dictionary = deltas[i]
		var positive: bool = d.get("positive", true)
		var col: Color = Tokens.color(Tokens.POSITIVE if positive else Tokens.NEGATIVE)
		var r: Rect2 = Rect2(x, y - fsize * 0.5, widths[i], fsize * 1.5)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Tokens.color("bg.deep")
		sb.border_color = col
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(Tokens.RADIUS_CHIP)
		draw_style_box(sb, r)
		draw_string(font, Vector2(x + 5.0, y + fsize * 0.45), str(d["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		x += widths[i] + 4.0
