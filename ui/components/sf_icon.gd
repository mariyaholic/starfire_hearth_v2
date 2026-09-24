class_name SfIcon
extends Control
## An icon from assets/icons, drawn crisp at the current UI scale and tinted with a token colour.

var icon_id: String = "":
	set(v):
		icon_id = v
		queue_redraw()
var outline: bool = false:
	set(v):
		outline = v
		queue_redraw()
## Logical size in pixels (the icon is square).
var icon_size: float = Tokens.ICON_L:
	set(v):
		icon_size = v
		_resize()
var color_token: String = "text.primary":
	set(v):
		color_token = v
		queue_redraw()
## When false the icon keeps its exact size; otherwise it grows with the text scale so icons next
## to text stay in proportion at 200%.
var scales_with_text: bool = true:
	set(v):
		scales_with_text = v
		_resize()
## Used instead of color_token when its alpha is above zero.
var color_override: Color = Color(0, 0, 0, 0):
	set(v):
		color_override = v
		queue_redraw()


static func make(p_icon: String, p_size: float = Tokens.ICON_L, p_token: String = "text.primary", p_outline: bool = false) -> SfIcon:
	var i: SfIcon = SfIcon.new()
	i.icon_id = p_icon
	i.icon_size = p_size
	i.color_token = p_token
	i.outline = p_outline
	return i


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size, icon_size)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	Layout.changed.connect(_resize)
	_resize()


## Drawn size in logical pixels.
func drawn_size() -> float:
	return icon_size * (Settings.text_scale if scales_with_text and is_inside_tree() else 1.0)


func _resize() -> void:
	var d: float = drawn_size()
	custom_minimum_size = Vector2(d, d)
	queue_redraw()


func tint() -> Color:
	return color_override if color_override.a > 0.0 else Tokens.color(color_token)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if icon_id.is_empty():
		return
	var d: float = drawn_size()
	var s: float = absf(get_global_transform_with_canvas().get_scale().x) * Layout.scale
	var px: int = ceili(d * maxf(s, 1.0))
	var tex: Texture2D = IconCache.texture(icon_id, px, outline)
	if tex == null:
		return
	var box: Vector2 = Vector2(d, d)
	draw_texture_rect(tex, Rect2((size - box) / 2.0, box), false, tint())
