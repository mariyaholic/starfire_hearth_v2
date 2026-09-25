class_name StoryScene
extends Control
## An event's story scene (§8.3, §15.7). When the painted scene for the id has been delivered it
## is shown; until then this draws the code placeholder from data/vignettes.json: a sky in the
## record's colours, a horizon of the named kind, silhouetted props and one accent light. Seeded
## by the id, so a scene always looks the same.

var vignette_id: String = ""
var _record: Dictionary = {}
var _texture: Texture2D = null


static func make(p_id: String, height: float = 180.0) -> StoryScene:
	var s: StoryScene = StoryScene.new()
	s.vignette_id = p_id
	s._record = Content.db().record("vignettes", p_id)
	s._texture = AssetIds.texture(p_id)
	s.custom_minimum_size = Vector2(0, height)
	# The painted scene is drawn at many sizes: smooth it with its mipmaps.
	if s._texture != null:
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	if _texture != null:
		_painted(w, h)
		return
	var sky: Array = DictIO.arr_of(_record, "sky")
	var top: Color = Tokens.color(str(sky[0])) if sky.size() > 0 else Tokens.color("bg.deep")
	var low: Color = Tokens.color(str(sky[1])) if sky.size() > 1 else Tokens.color("bg.panel")
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = top.darkened(0.2)
	frame.set_corner_radius_all(Tokens.RADIUS_PANEL)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var rng: RngStream = Rng.stream(Rng.salt_of(vignette_id), 0, Rng.GEN, 11)
	# Sky: six bands blending from the top colour to the horizon colour.
	var sky_h: float = h * 0.64
	for i in 6:
		var t: float = i / 5.0
		draw_rect(Rect2(4, 4 + sky_h * i / 6.0, w - 8, sky_h / 6.0 + 1), top.lerp(low, t * t))
	for i in 22:
		var p: Vector2 = Vector2(8 + rng.range(0, int(w - 16)), 6 + rng.range(0, int(sky_h * 0.55)))
		draw_circle(p, 0.8 + rng.range(0, 10) / 10.0, Color(1, 1, 1, 0.55), true, -1.0, true)
	var accent: Color = Tokens.color(DictIO.str_of(_record, "accent_token", "hearth.gold"))
	_accent(DictIO.str_of(_record, "accent", "star"), accent, w, h, sky_h)
	var ground: Color = Tokens.color(DictIO.str_of(_record, "ground", "bg.panel.alt"))
	_horizon(DictIO.str_of(_record, "horizon", "plain"), ground, top, w, h, sky_h, rng)
	var props: Array = DictIO.arr_of(_record, "props")
	for i in props.size():
		_prop(str(props[i]), i, props.size(), ground.darkened(0.45), accent, w, h, rng)


## The delivered scene, cropped around its centre (where §15.7 keeps the subject) to fill the box
## without stretching, with the panel's rounded corners.
func _painted(w: float, h: float) -> void:
	var ts: Vector2 = _texture.get_size()
	var src: Rect2 = Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > w / h:
		src.size.x = ts.y * w / h
		src.position.x = (ts.x - src.size.x) / 2.0
	else:
		src.size.y = ts.x * h / w
		src.position.y = (ts.y - src.size.y) / 2.0
	var pts: PackedVector2Array = rounded_rect(Rect2(0, 0, w, h), minf(Tokens.RADIUS_PANEL, minf(w, h) / 2.0))
	var uvs: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		uvs.append((src.position + p / Vector2(w, h) * src.size) / ts)
	draw_colored_polygon(pts, Color.WHITE, uvs, _texture)


## A rounded rectangle as a polygon: four corner arcs of six steps each.
static func rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var centres: Array[Vector2] = [
		Vector2(r.end.x - radius, r.position.y + radius), r.end - Vector2(radius, radius),
		Vector2(r.position.x + radius, r.end.y - radius), r.position + Vector2(radius, radius)]
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 4:
		for s in 7:
			var a: float = -PI / 2.0 + (i + s / 6.0) * PI / 2.0
			pts.append(centres[i] + Vector2(cos(a), sin(a)) * radius)
	return pts


func _accent(kind: String, col: Color, w: float, h: float, sky_h: float) -> void:
	match kind:
		"star", "flare":
			var c: Vector2 = Vector2(w * 0.74, sky_h * 0.78)
			draw_circle(c, h * (0.2 if kind == "flare" else 0.14), Color(col, 0.28), true, -1.0, true)
			draw_circle(c, h * 0.08, col, true, -1.0, true)
		"beacon":
			var b: Vector2 = Vector2(w * 0.5, sky_h * 0.45)
			draw_line(b + Vector2(0, -h * 0.12), b + Vector2(0, h * 0.12), Color(col, 0.6), 2.0, true)
			draw_circle(b, h * 0.05, col, true, -1.0, true)
		"glow", "lamp", "lantern", "window":
			draw_circle(Vector2(w * 0.3, sky_h * 0.85), h * 0.22, Color(col, 0.16), true, -1.0, true)


func _horizon(kind: String, ground: Color, sky: Color, w: float, h: float, sky_h: float, rng: RngStream) -> void:
	var base_y: float = sky_h
	var pts: PackedVector2Array = PackedVector2Array([Vector2(4, h - 4)])
	match kind:
		"hills", "terraces", "dunes":
			for i in 11:
				var x: float = 4 + (w - 8) * i / 10.0
				var bump: float = sin(i * 1.3 + rng.range(0, 10) / 10.0) * h * (0.06 if kind != "dunes" else 0.04)
				if kind == "terraces":
					bump = -h * 0.03 * (i % 3)
				pts.append(Vector2(x, base_y + bump))
		"hall", "vault", "station":
			# An interior: a wall with an arch or a long window, then the floor.
			draw_rect(Rect2(4, 4, w - 8, sky_h), Color(ground.darkened(0.3), 0.85))
			var arch_w: float = w * 0.36
			var arch: Rect2 = Rect2((w - arch_w) / 2.0, sky_h * 0.18, arch_w, sky_h * 0.7)
			draw_rect(arch, Color(sky, 0.9))
			draw_circle(Vector2(w / 2.0, arch.position.y), arch_w / 2.0, Color(sky, 0.9), true, -1.0, true)
			pts.append(Vector2(4, base_y))
			pts.append(Vector2(w - 4, base_y))
		"space":
			draw_circle(Vector2(w * 0.2, h * 1.35), h * 0.8, Color(ground, 0.9), true, -1.0, true)
			return
		"sea":
			pts.append(Vector2(4, base_y + h * 0.04))
			pts.append(Vector2(w - 4, base_y + h * 0.04))
		_:
			pts.append(Vector2(4, base_y + h * 0.02))
			pts.append(Vector2(w - 4, base_y + h * 0.02))
	pts.append(Vector2(w - 4, h - 4))
	draw_colored_polygon(pts, ground)


func _prop(kind: String, i: int, n: int, col: Color, accent: Color, w: float, h: float, rng: RngStream) -> void:
	var x: float = w * (0.18 + 0.64 * (i + 0.5) / maxf(1.0, n))
	var y: float = h * 0.9
	var s: float = h * 0.12
	match kind:
		"figure", "crowd", "figures":
			var count: int = 1 if kind == "figure" else (3 if kind == "figures" else 6)
			for k in count:
				var fx: float = x + (k - count / 2.0) * s * 0.55
				draw_colored_polygon(PackedVector2Array([Vector2(fx - s * 0.18, y), Vector2(fx - s * 0.12, y - s * 0.7), Vector2(fx + s * 0.12, y - s * 0.7), Vector2(fx + s * 0.18, y)]), col)
				draw_circle(Vector2(fx, y - s * 0.85), s * 0.14, col, true, -1.0, true)
		"dome", "domes", "pods":
			var count2: int = 1 if kind == "dome" else 3
			for k in count2:
				draw_circle(Vector2(x + (k - 1) * s * 0.9, y), s * (0.5 if kind != "pods" else 0.3), col, true, -1.0, true)
		"tower", "towers", "pylons", "column", "beacon", "dish":
			var count3: int = 1 if kind in ["tower", "column", "beacon", "dish"] else 3
			for k in count3:
				var tx: float = x + (k - 1) * s * 0.7
				draw_rect(Rect2(tx - s * 0.08, y - s * 1.6, s * 0.16, s * 1.6), col)
				if kind == "beacon":
					draw_circle(Vector2(tx, y - s * 1.7), s * 0.14, accent, true, -1.0, true)
		"machines", "drive", "scaffold", "crate", "market", "tent", "ruins", "stretchers":
			draw_rect(Rect2(x - s * 0.6, y - s * 0.7, s * 1.2, s * 0.7), col)
			draw_rect(Rect2(x - s * 0.3, y - s * 1.1, s * 0.6, s * 0.4), col)
		"window", "lamp", "banners", "lectern", "lights":
			draw_rect(Rect2(x - s * 0.25, y - s * 1.2, s * 0.5, s * 0.35), Color(accent, 0.85))
		"fields":
			for k in 4:
				draw_line(Vector2(w * 0.08, y - k * s * 0.18), Vector2(w * 0.92, y - k * s * 0.22), Color(col.lightened(0.2), 0.8), 2.0, true)
		"ship", "ships", "slowboat", "drone":
			var count4: int = 3 if kind == "ships" else 1
			for k in count4:
				var sx: float = x + (k - 1) * s
				var sy: float = h * 0.35 + rng.range(0, int(h * 0.1))
				draw_colored_polygon(PackedVector2Array([Vector2(sx - s * 0.5, sy), Vector2(sx + s * 0.5, sy - s * 0.12), Vector2(sx + s * 0.5, sy + s * 0.12)]), col.lightened(0.25))
		"comet", "debris", "flare", "planet", "nebula", "stars":
			var cy: float = h * 0.28
			draw_circle(Vector2(x, cy), s * 0.25, accent.lightened(0.3), true, -1.0, true)
			draw_line(Vector2(x, cy), Vector2(x - s * 1.4, cy - s * 0.4), Color(accent, 0.5), 3.0, true)
