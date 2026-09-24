class_name Meter
extends Control
## A horizontal bar for a value in a range, with optional threshold ticks (stability 15/30/70,
## Noise 25/50/75) and a fill colour that can change past each threshold. Numbers belong in a
## label next to the meter, inside an Explainable.

var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()
var max_value: float = 100.0
var fill_token: String = "accent.teal"
## [{"at": 70.0, "token": "ok.green"}] -- from `at` upward the fill takes that colour.
var bands: Array[Dictionary] = []
var ticks: Array[float] = []
var bar_height: float = 8.0


static func make(p_value: float, p_max: float, p_fill: String, p_ticks: Array[float] = [], p_bands: Array[Dictionary] = []) -> Meter:
	var m: Meter = Meter.new()
	m.max_value = p_max
	m.fill_token = p_fill
	m.ticks = p_ticks
	m.bands = p_bands
	m.value = p_value
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(80, 14)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func fill_color() -> Color:
	var token: String = fill_token
	for b: Dictionary in bands:
		if value >= float(b["at"]):
			token = b["token"]
	return Tokens.color(token)


func _draw() -> void:
	var y: float = (size.y - bar_height) / 2.0
	var r: Rect2 = Rect2(0, y, size.x, bar_height)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Tokens.color("bg.deep")
	bg.set_corner_radius_all(int(bar_height / 2.0))
	if Tokens.high_contrast:
		bg.border_color = Tokens.color("line.subtle")
		bg.set_border_width_all(1)
	draw_style_box(bg, r)
	var frac: float = clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	if frac > 0.0:
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = fill_color()
		fill.set_corner_radius_all(int(bar_height / 2.0))
		draw_style_box(fill, Rect2(0, y, maxf(bar_height, size.x * frac), bar_height))
	for t: float in ticks:
		var x: float = size.x * clampf(t / max_value, 0.0, 1.0)
		draw_line(Vector2(x, y - 3.0), Vector2(x, y + bar_height + 3.0), Tokens.color("text.secondary"), 2.0, true)
