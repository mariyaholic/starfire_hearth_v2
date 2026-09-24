class_name NoiseWave
extends Control
## The Noise meter of the top bar (§5.9): a small waveform whose height and jaggedness grow with
## Noise. The three thresholds (25, 50, 75) are drawn as faint guide lines, and past 50 the wave
## turns gold, past 75 ember. The number itself sits in an Explainable label beside it.

var noise: float = 0.0:
	set(v):
		noise = clampf(v, 0.0, 100.0)
		queue_redraw()
var _phase: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 28)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	set_process(not Settings.reduce_motion)
	Settings.changed.connect(func(_k: String) -> void: set_process(not Settings.reduce_motion))


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * (0.6 + noise / 60.0), TAU)
	queue_redraw()


func wave_color() -> Color:
	if noise >= 75.0:
		return Tokens.color("alert.ember")
	if noise >= 50.0:
		return Tokens.color("hearth.gold")
	return Tokens.color("sci.cyan")


func _draw() -> void:
	var mid: float = size.y / 2.0
	for th: float in [25.0, 50.0, 75.0]:
		var h: float = (size.y / 2.0 - 2.0) * th / 100.0
		draw_line(Vector2(0, mid - h), Vector2(size.x, mid - h), Color(Tokens.color("line.subtle"), 0.6), 1.0)
	var amp: float = (size.y / 2.0 - 2.0) * maxf(noise, 4.0) / 100.0
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 36
	var jag: float = noise / 100.0
	for i in n + 1:
		var t: float = float(i) / n
		var x: float = t * size.x
		var env: float = sin(t * PI)
		var y: float = sin(t * TAU * 2.0 + _phase) * 0.7 + sin(t * TAU * 5.3 - _phase * 1.7) * 0.3 * jag
		pts.append(Vector2(x, mid - y * amp * env))
	draw_polyline(pts, wave_color(), 2.0, true)
