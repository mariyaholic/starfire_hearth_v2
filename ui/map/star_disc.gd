class_name StarDisc
extends Control
## A star as a glowing disc (§8.3): layered radial glows baked once into a texture and tinted by
## spectral class, sized by magnitude. Binary systems draw a smaller companion.

const GLOW_PX: int = 128

static var _glow: Texture2D = null

var spectral: String = "G":
	set(v):
		spectral = v
		queue_redraw()
## 1 (dim) .. 5 (bright).
var magnitude: int = 3:
	set(v):
		magnitude = clampi(v, 1, 5)
		queue_redraw()


static func make(p_spectral: String, p_magnitude: int, p_size: float = 64.0) -> StarDisc:
	var s: StarDisc = StarDisc.new()
	s.spectral = p_spectral
	s.magnitude = p_magnitude
	s.custom_minimum_size = Vector2(p_size, p_size)
	return s


static func glow_texture() -> Texture2D:
	if _glow == null:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
		var t: GradientTexture2D = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = GLOW_PX
		t.height = GLOW_PX
		_glow = t
	return _glow


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)


func star_color() -> Color:
	return Tokens.STAR.get(spectral, Tokens.STAR["G"])


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var half: float = minf(size.x, size.y) / 2.0
	var core: float = half * (0.18 + 0.045 * magnitude)
	if spectral == "white_dwarf":
		core *= 0.55
	if spectral == "binary":
		_star(c + Vector2(-core * 0.55, -core * 0.2), core * 0.8, Tokens.STAR["G"], half)
		_star(c + Vector2(core * 0.9, core * 0.45), core * 0.5, Tokens.STAR["M"], half * 0.7)
		return
	_star(c, core, star_color(), half)


func _star(center: Vector2, core: float, col: Color, half: float) -> void:
	var tex: Texture2D = glow_texture()
	var outer: float = minf(half, core * 3.2)
	draw_texture_rect(tex, Rect2(center - Vector2(outer, outer), Vector2(outer, outer) * 2.0), false, Color(col, 0.8))
	var inner: float = core * 1.8
	draw_texture_rect(tex, Rect2(center - Vector2(inner, inner), Vector2(inner, inner) * 2.0), false, Color(col.lerp(Color.WHITE, 0.2), 1.0))
	draw_circle(center, core, col.lerp(Color.WHITE, 0.25), true, -1.0, true)
	draw_circle(center - Vector2(core, core) * 0.22, core * 0.45, Color(1, 1, 1, 0.55), true, -1.0, true)
