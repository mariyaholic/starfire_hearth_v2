class_name PlanetDisc
extends Control
## A planet generated from its type and a seed (§8.3): a flat disc with two or three bands or
## patches in the type's palette (data/planet_types.json), a soft terminator crescent and a thin
## rim light. Gas giants may have rings; asteroid belts are a scatter of rocks. The shapes are
## computed once per size, type and seed, then cached.

var planet_type: String = "barren"
var palette: Array[Color] = []
var art_seed: int = 0
var _cache_key: String = ""
var _shapes: Array[Dictionary] = []
var _back: Array[Dictionary] = []


static func make(p_type: String, p_palette: Array, p_seed: int, p_size: float = 96.0) -> PlanetDisc:
	var p: PlanetDisc = PlanetDisc.new()
	p.planet_type = p_type
	p.art_seed = p_seed
	for c: Variant in p_palette:
		p.palette.append(Color(str(c)) if typeof(c) == TYPE_STRING else c)
	p.custom_minimum_size = Vector2(p_size, p_size)
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pal(i: int) -> Color:
	if palette.is_empty():
		return Tokens.color("mineral.slate")
	return palette[mini(i, palette.size() - 1)]


func _draw() -> void:
	var key: String = "%s|%s|%d" % [size, planet_type, art_seed]
	if key != _cache_key:
		_cache_key = key
		_build()
	for s: Dictionary in _back:
		_emit(s)
	for s: Dictionary in _shapes:
		_emit(s)


func _emit(s: Dictionary) -> void:
	match str(s["kind"]):
		"poly":
			draw_colored_polygon(s["pts"], s["color"])
		"circle":
			draw_circle(s["c"], s["r"], s["color"], true, -1.0, true)
		"arc":
			draw_arc(s["c"], s["r"], s["a0"], s["a1"], 48, s["color"], s["w"], true)
		"line":
			draw_polyline(s["pts"], s["color"], s["w"], true)


func _build() -> void:
	_shapes.clear()
	_back.clear()
	var rng: RngStream = Rng.stream(art_seed, 0, Rng.GEN, Rng.salt_of("planet_art:" + planet_type))
	var c: Vector2 = size / 2.0
	var half: float = minf(size.x, size.y) / 2.0
	if planet_type == "asteroid_belt":
		_belt(rng, c, half)
		return
	var ringed: bool = planet_type == "gas_giant" and rng.chance_bp(7000)
	var r: float = half * (0.62 if ringed else 0.9)
	var disc: PackedVector2Array = _circle(c, r, 72)
	if ringed:
		_rings(rng, c, r, true)
	_shapes.append({"kind": "poly", "pts": disc, "color": _pal(0)})
	match planet_type:
		"gas_giant":
			var n: int = 4 + rng.range(0, 2)
			for i in n:
				var y0: float = -r + (2.0 * r) * (i + 0.5) / (n + 0.5) + _rf(rng, -r * 0.05, r * 0.05)
				_band(rng, disc, c, y0, _rf(rng, r * 0.08, r * 0.2), _pal(1 + i % 3), r)
		"continental":
			for i in 3:
				_blob(rng, disc, c, r, _rf(rng, 0.28, 0.45), _pal(1))
			for i in 2:
				_blob(rng, disc, c, r, _rf(rng, 0.12, 0.2), _pal(2))
			_band(rng, disc, c, _rf(rng, -r * 0.5, -r * 0.2), r * 0.07, Color(_pal(3), 0.55), r)
			_band(rng, disc, c, _rf(rng, r * 0.2, r * 0.55), r * 0.06, Color(_pal(3), 0.45), r)
		"ocean":
			_band(rng, disc, c, _rf(rng, -r * 0.3, 0.0), r * 0.12, Color(_pal(1), 0.8), r)
			for i in 3:
				_blob(rng, disc, c, r, _rf(rng, 0.07, 0.12), _pal(2))
			_band(rng, disc, c, _rf(rng, -r * 0.6, -r * 0.35), r * 0.06, Color(_pal(3), 0.6), r)
			_band(rng, disc, c, _rf(rng, r * 0.25, r * 0.5), r * 0.05, Color(_pal(3), 0.5), r)
		"arid":
			_band(rng, disc, c, _rf(rng, -r * 0.4, -r * 0.1), r * 0.16, _pal(1), r)
			_band(rng, disc, c, _rf(rng, r * 0.2, r * 0.5), r * 0.12, _pal(2), r)
			for i in 2:
				_blob(rng, disc, c, r, _rf(rng, 0.1, 0.18), _pal(3))
		"ice":
			for i in 3:
				_blob(rng, disc, c, r, _rf(rng, 0.2, 0.35), _pal(1))
			_blob(rng, disc, c, r, _rf(rng, 0.3, 0.4), Color(_pal(2), 0.8))
			for i in 3:
				_crack(rng, c, r, _pal(3))
		"barren":
			for i in 2:
				_blob(rng, disc, c, r, _rf(rng, 0.25, 0.4), _pal(1))
			for i in 5:
				_crater(rng, c, r)
		"toxic":
			for i in 3:
				var y0: float = -r * 0.6 + i * r * 0.6 + _rf(rng, -r * 0.1, r * 0.1)
				_band(rng, disc, c, y0, _rf(rng, r * 0.1, r * 0.18), _pal(1 + i % 2), r)
			for i in 2:
				_blob(rng, disc, c, r, _rf(rng, 0.08, 0.12), _pal(3))
	# Terminator: shadow on the far side from a light at the upper left, in two soft steps.
	var light: Vector2 = Vector2(-0.62, -0.78)
	for step: Array in [[0.55, 0.28], [0.3, 0.3]]:
		var off: PackedVector2Array = _circle(c + light * r * float(step[0]), r * 1.02, 72)
		for piece: PackedVector2Array in Geometry2D.clip_polygons(disc, off):
			_shapes.append({"kind": "poly", "pts": piece, "color": Color(Tokens.color("bg.deep"), float(step[1]))})
	var la: float = light.angle()
	_shapes.append({"kind": "arc", "c": c, "r": r - 1.0, "a0": la - 1.1, "a1": la + 1.1, "w": 2.0, "color": Color(_pal(3), 0.8)})
	if ringed:
		_rings(rng, c, r, false)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: float = TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _rf(rng: RngStream, lo: float, hi: float) -> float:
	return lo + (hi - lo) * rng.range(0, 10000) / 10000.0


func _clip_add(shape: PackedVector2Array, disc: PackedVector2Array, col: Color) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, disc):
		_shapes.append({"kind": "poly", "pts": piece, "color": col})


## A wavy horizontal band clipped to the disc.
func _band(rng: RngStream, disc: PackedVector2Array, c: Vector2, y0: float, thick: float, col: Color, r: float) -> void:
	var amp: float = _rf(rng, r * 0.02, r * 0.06)
	var k: float = _rf(rng, 1.5, 3.5)
	var ph: float = _rf(rng, 0.0, TAU)
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	var n: int = 24
	for i in n + 1:
		var t: float = float(i) / n
		var x: float = -r * 1.2 + t * r * 2.4
		var w: float = sin(t * k * TAU + ph) * amp
		top.append(c + Vector2(x, y0 - thick / 2.0 + w))
		bottom.append(c + Vector2(x, y0 + thick / 2.0 + w * 0.7))
	bottom.reverse()
	var poly: PackedVector2Array = top
	poly.append_array(bottom)
	_clip_add(poly, disc, col)


## An irregular patch (continent, ice field, dark plain) clipped to the disc.
func _blob(rng: RngStream, disc: PackedVector2Array, c: Vector2, r: float, rel: float, col: Color) -> void:
	var at: Vector2 = c + Vector2(_rf(rng, -0.6, 0.6), _rf(rng, -0.6, 0.6)) * r
	var br: float = r * rel
	var n: int = 14
	var pts: PackedVector2Array = PackedVector2Array()
	var wob: Array[float] = []
	for i in n:
		wob.append(_rf(rng, 0.7, 1.25))
	for i in n:
		var a: float = TAU * i / n
		var f: float = (wob[i] * 2.0 + wob[(i + 1) % n] + wob[(i + n - 1) % n]) / 4.0
		pts.append(at + Vector2(cos(a), sin(a) * 0.8) * br * f)
	_clip_add(pts, disc, col)


func _crater(rng: RngStream, c: Vector2, r: float) -> void:
	var at: Vector2 = c + Vector2(_rf(rng, -0.55, 0.55), _rf(rng, -0.55, 0.55)) * r
	var cr: float = r * _rf(rng, 0.06, 0.14)
	_shapes.append({"kind": "circle", "c": at, "r": cr, "color": _pal(1).darkened(0.12)})
	_shapes.append({"kind": "arc", "c": at, "r": cr, "a0": PI * 0.9, "a1": PI * 1.9, "w": 1.5, "color": _pal(2)})


func _crack(rng: RngStream, c: Vector2, r: float, col: Color) -> void:
	var p: Vector2 = c + Vector2(_rf(rng, -0.5, 0.5), _rf(rng, -0.5, 0.5)) * r
	var pts: PackedVector2Array = PackedVector2Array([p])
	for i in 3:
		p += Vector2(_rf(rng, -0.25, 0.25), _rf(rng, -0.25, 0.25)) * r
		pts.append(p)
	_shapes.append({"kind": "line", "pts": pts, "w": 1.5, "color": Color(col, 0.7)})


## Ring arcs: the back half before the planet, the front half after it.
func _rings(rng: RngStream, c: Vector2, r: float, back: bool) -> void:
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
