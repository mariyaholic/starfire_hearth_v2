class_name ShowcaseVignette
extends Control
## A sample flat event vignette (§8.3): sky gradient, horizon, midground silhouettes, a foreground
## figure and a light accent. From M1 vignettes are defined in data/vignettes.json and assembled
## from the same kinds of layers; this one is fixed so the look can be judged now.


func _init() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var clip: StyleBoxFlat = StyleBoxFlat.new()
	clip.bg_color = Color("#10304A")
	clip.set_corner_radius_all(Tokens.RADIUS_PANEL)
	draw_style_box(clip, Rect2(Vector2.ZERO, size))
	# Sky: three bands from deep blue to a warm horizon.
	var bands: Array[Color] = [Color("#12304C"), Color("#1D4466"), Color("#3A5F7E"), Color("#C98A5A")]
	for i in bands.size():
		var y0: float = h * 0.62 * i / bands.size()
		draw_rect(Rect2(8, y0 + 4, w - 16, h * 0.62 / bands.size() + 1), bands[i])
	# Stars.
	var rng: RngStream = Rng.stream(97, 0, Rng.GEN, 5)
	for i in 18:
		var p: Vector2 = Vector2(12 + rng.range(0, int(w - 24)), 8 + rng.range(0, int(h * 0.35)))
		draw_circle(p, 1.0 + rng.range(0, 10) / 10.0, Color(1, 1, 1, 0.7), true, -1.0, true)
	# The K star low on the horizon.
	var sun: Vector2 = Vector2(w * 0.72, h * 0.6)
	draw_circle(sun, h * 0.16, Color(Tokens.STAR["K"], 0.35), true, -1.0, true)
	draw_circle(sun, h * 0.09, Tokens.STAR["K"], true, -1.0, true)
	# Far hills.
	var far: PackedVector2Array = PackedVector2Array([Vector2(8, h * 0.66)])
	for i in 9:
		far.append(Vector2(8 + (w - 16) * i / 8.0, h * (0.6 + 0.05 * sin(i * 1.7))))
	far.append(Vector2(w - 8, h * 0.66))
	far.append(Vector2(w - 8, h - 4))
	far.append(Vector2(8, h - 4))
	draw_colored_polygon(far, Color("#233B52"))
	# Midground: the colony's domes and the Ark hull.
	var ground: Color = Color("#172A3C")
	draw_rect(Rect2(8, h * 0.74, w - 16, h * 0.26 - 4), ground)
	for d: Array in [[0.18, 0.12], [0.3, 0.08], [0.5, 0.1]]:
		var c: Vector2 = Vector2(w * float(d[0]), h * 0.75)
		draw_circle(c, h * float(d[1]), Color("#2A4A6B"), true, -1.0, true)
	draw_rect(Rect2(8, h * 0.75, w - 16, h * 0.25 - 4), ground)
	var hull: PackedVector2Array = PackedVector2Array([
		Vector2(w * 0.58, h * 0.75), Vector2(w * 0.62, h * 0.5), Vector2(w * 0.66, h * 0.46),
		Vector2(w * 0.7, h * 0.5), Vector2(w * 0.74, h * 0.75),
	])
	draw_colored_polygon(hull, Color("#1B3350"))
	# Light accents: lit windows in the hall.
	for i in 5:
		draw_rect(Rect2(w * 0.12 + i * w * 0.06, h * 0.79, w * 0.02, h * 0.03), Color(Tokens.color("hearth.gold"), 0.9))
	# Foreground figure: the archivist with a lamp.
	var fx: float = w * 0.86
	var fy: float = h * 0.96
	draw_colored_polygon(PackedVector2Array([Vector2(fx - 12, fy), Vector2(fx - 7, fy - 34), Vector2(fx + 7, fy - 34), Vector2(fx + 12, fy)]), Color("#0B1622"))
	draw_circle(Vector2(fx, fy - 41), 7.0, Color("#0B1622"), true, -1.0, true)
	draw_circle(Vector2(fx + 14, fy - 24), 4.0, Tokens.color("hearth.gold"), true, -1.0, true)
	draw_circle(Vector2(fx + 14, fy - 24), 10.0, Color(Tokens.color("hearth.gold"), 0.2), true, -1.0, true)
