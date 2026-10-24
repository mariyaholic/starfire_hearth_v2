class_name Starfield
extends Control
## The title screen's sky (§7 screen 1): a seeded field of stars that twinkle, and three faint
## hyperlanes between bright stars with a slow pulse travelling along each. The same sky every
## time. Reduce motion keeps it still. It never takes input.

const STARS: int = 170
const BRIGHT: int = 7
const PULSE_SECONDS: float = 9.0

## Positions are fractions of the rect, so the sky reflows with the window.
var _pos: Array[Vector2] = []
var _radius: Array[float] = []
var _phase: Array[float] = []
var _tint: Array[Color] = []
## Pairs of indexes into the bright stars at the front of the arrays.
var _lanes: Array[Vector2i] = [Vector2i(0, 2), Vector2i(2, 4), Vector2i(1, 5)]
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng: RngStream = Rng.stream(Rng.salt_of("title_sky"), 0, Rng.GEN, 3)
	var bright_tints: Array[Color] = [Tokens.STAR["K"], Tokens.STAR["G"], Tokens.STAR["F"], Tokens.STAR["A"]]
	for i in STARS:
		_pos.append(Vector2(rng.range(20, 980) / 1000.0, rng.range(20, 980) / 1000.0))
		var bright: bool = i < BRIGHT
		_radius.append(rng.range(22, 34) / 10.0 if bright else rng.range(5, 16) / 10.0)
		_phase.append(rng.range(0, 628) / 100.0)
		_tint.append(bright_tints[rng.range(0, bright_tints.size() - 1)] if bright else Color(1, 1, 1))


func _ready() -> void:
	Settings.changed.connect(_on_setting)
	set_process(not Settings.reduce_motion)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var moving: bool = not Settings.reduce_motion
	var lane_col: Color = Tokens.color("accent.teal")
	for k in _lanes.size():
		var a: Vector2 = _pos[_lanes[k].x] * s
		var b: Vector2 = _pos[_lanes[k].y] * s
		draw_line(a, b, Color(lane_col, 0.16), 1.5, true)
		# The pulse: a small glow that travels the lane; each lane is a third of a cycle apart.
		var f: float = fposmod(_t / PULSE_SECONDS + k / 3.0, 1.0) if moving else 0.5
		var p: Vector2 = a.lerp(b, f)
		draw_circle(p, 7.0, Color(lane_col, 0.12), true, -1.0, true)
		draw_circle(p, 2.5, Color(lane_col, 0.7), true, -1.0, true)
	for i in _pos.size():
		var twinkle: float = 0.75 + 0.25 * sin(_t * 0.9 + _phase[i]) if moving else 0.85
		var c: Vector2 = _pos[i] * s
		if i < BRIGHT:
			draw_circle(c, _radius[i] * 3.2, Color(_tint[i], 0.10 * twinkle), true, -1.0, true)
		draw_circle(c, _radius[i], Color(_tint[i], 0.8 * twinkle), true, -1.0, true)


func _on_setting(key: String) -> void:
	if key == "reduce_motion":
		set_process(not Settings.reduce_motion)
		queue_redraw()
