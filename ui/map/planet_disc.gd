class_name PlanetDisc
extends Control
## A planet generated from its type and a seed (§8.3). Worlds are lit spheres drawn by
## ui/map/planet_sphere.gdshader: a painted-looking surface in the type's palette
## (data/planet_types.json), a soft terminator, a rim light and an atmosphere glow. Some gas giants
## have rings, drawn in two halves around the sphere; asteroid belts are a scatter of rocks. The
## shapes are computed once per size, type and seed.

const SPHERE_SHADER: String = "res://ui/map/planet_sphere.gdshader"
## Planet type -> [shader kind, atmosphere strength].
const SPHERES: Dictionary[String, Array] = {
	"continental": [0, 0.8], "ocean": [1, 0.9], "arid": [2, 0.35], "ice": [3, 0.45],
	"barren": [4, 0.0], "toxic": [5, 0.8], "gas_giant": [6, 0.6],
}

static var _shader: Shader = null

var planet_type: String = "barren"
var palette: Array[Color] = []
var art_seed: int = 0
var _cache_key: String = ""
var _shapes: Array[Dictionary] = []
var _back: Array[Dictionary] = []
var _ringed: bool = false
var _sphere: ColorRect = null
var _front: Control = null


static func make(p_type: String, p_palette: Array, p_seed: int, p_size: float = 96.0) -> PlanetDisc:
	var p: PlanetDisc = PlanetDisc.new()
	p.planet_type = p_type
	p.art_seed = p_seed
	for c: Variant in p_palette:
		p.palette.append(Color(str(c)) if typeof(c) == TYPE_STRING else c)
	p.custom_minimum_size = Vector2(p_size, p_size)
	p._make_sphere()
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pal(i: int) -> Color:
	if palette.is_empty():
		return Tokens.color("mineral.slate")
	return palette[mini(i, palette.size() - 1)]


func _make_sphere() -> void:
	if not SPHERES.has(planet_type):
		return
	var rng: RngStream = Rng.stream(art_seed, 0, Rng.GEN, Rng.salt_of("planet_art:" + planet_type))
	_ringed = planet_type == "gas_giant" and rng.chance_bp(7000)
	if _shader == null:
		_shader = load(SPHERE_SHADER) as Shader
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("kind", int(SPHERES[planet_type][0]))
	mat.set_shader_parameter("atmosphere", float(SPHERES[planet_type][1]))
	for i in 4:
		mat.set_shader_parameter("c%d" % i, _pal(i))
	mat.set_shader_parameter("glow", _pal(3).lerp(_pal(0), 0.35).lightened(0.2))
	mat.set_shader_parameter("seed", float(art_seed % 997) + 0.5)
	mat.set_shader_parameter("radius", 0.31 if _ringed else 0.44)
	_sphere = ColorRect.new()
	_sphere.name = "Sphere"
	_sphere.material = mat
	_sphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sphere)
	if _ringed:
		# The near half of the rings goes over the sphere.
		_front = Control.new()
		_front.name = "RingsFront"
		_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_front.draw.connect(_draw_front)
		add_child(_front)


func _draw() -> void:
	var key: String = "%s|%s|%d" % [size, planet_type, art_seed]
	if key != _cache_key:
		_cache_key = key
		_build()
		if _front != null:
			_front.queue_redraw()
	for s: Dictionary in _back:
		_emit(self, s)
	if _sphere == null:
		for s2: Dictionary in _shapes:
			_emit(self, s2)


func _draw_front() -> void:
	for s: Dictionary in _shapes:
		_emit(_front, s)


static func _emit(on: CanvasItem, s: Dictionary) -> void:
	match str(s["kind"]):
		"poly":
			on.draw_colored_polygon(s["pts"], s["color"])
		"circle":
			on.draw_circle(s["c"], s["r"], s["color"], true, -1.0, true)
		"arc":
			on.draw_arc(s["c"], s["r"], s["a0"], s["a1"], 48, s["color"], s["w"], true)
		"line":
			on.draw_polyline(s["pts"], s["color"], s["w"], true)


func _build() -> void:
	_shapes.clear()
	_back.clear()
	var c: Vector2 = size / 2.0
	var half: float = minf(size.x, size.y) / 2.0
	if planet_type == "asteroid_belt":
		_belt(Rng.stream(art_seed, 0, Rng.GEN, Rng.salt_of("planet_art:" + planet_type)), c, half)
		return
	if _ringed:
		# The sphere's radius in pixels: the shader's radius is a fraction of the rect.
		var r: float = minf(size.x, size.y) * 0.31
		_rings(c, r, true)
		_rings(c, r, false)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


func _rf(rng: RngStream, lo: float, hi: float) -> float:
	return lo + (hi - lo) * rng.range(0, 10000) / 10000.0


## Ring arcs: the back half before the planet, the front half after it.
func _rings(c: Vector2, r: float, back: bool) -> void:
	var tilt: float = 0.3
	var target: Array[Dictionary] = _back if back else _shapes
	for i in 2:
		var rr: float = r * (1.35 + i * 0.22)
		var pts: PackedVector2Array = PackedVector2Array()
		var a0: float = PI if back else 0.0
		for k in 33:
			var a: float = a0 + PI * k / 32.0
			pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * tilt))
		target.append({"kind": "line", "pts": pts, "w": 3.0 - i, "color": Color(_pal(3), 0.85 - i * 0.25)})


func _belt(rng: RngStream, c: Vector2, half: float) -> void:
	var rx: float = half * 0.9
	var ry: float = half * 0.42
	for i in 40:
		var a: float = _rf(rng, 0.0, TAU)
		var d: float = _rf(rng, 0.8, 1.08)
		var at: Vector2 = c + Vector2(cos(a) * rx * d, sin(a) * ry * d)
		var rr: float = half * _rf(rng, 0.035, 0.09)
		var n: int = 6
		var pts: PackedVector2Array = PackedVector2Array()
		for k in n:
			var ang: float = TAU * k / n
			pts.append(at + Vector2(cos(ang), sin(ang)) * rr * _rf(rng, 0.7, 1.2))
		_shapes.append({"kind": "poly", "pts": pts, "color": _pal(rng.range(1, 3))})
		_shapes.append({"kind": "line", "pts": _closed(pts), "w": 1.0, "color": _pal(3)})
