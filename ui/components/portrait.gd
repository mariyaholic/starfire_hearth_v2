class_name Portrait
extends Control
## A speaking character (§8.3, §15.7). The delivered portrait for the id and expression is shown
## when it exists (the neutral one otherwise); until then this draws the code placeholder from
## data/portraits.json: a bust on a disc in the character's skin, hair and collar colours. The
## Vael envoy is a spiral of seven lights whose brightness follows the expression.

const EXPRESSIONS: Array[String] = ["neutral", "warm", "worried", "stern"]

var portrait_id: String = ""
var expression: String = "neutral"
var _record: Dictionary = {}
var _texture: Texture2D = null


static func make(p_id: String, p_expression: String = "neutral", p_size: float = 96.0) -> Portrait:
	var p: Portrait = Portrait.new()
	p.portrait_id = p_id
	p.expression = p_expression if EXPRESSIONS.has(p_expression) else "neutral"
	p._record = Content.db().record("portraits", p_id)
	p._texture = AssetIds.texture(p_id + "__" + p.expression) if p.expression != "neutral" else null
	if p._texture == null:
		p._texture = AssetIds.texture(p_id)
	p.custom_minimum_size = Vector2(p_size, p_size)
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size / 2.0
	var r: float = s / 2.0
	draw_circle(c, r, Tokens.color("bg.panel.alt"), true, -1.0, true)
	if _texture != null:
		draw_texture_rect(_texture, Rect2(c - Vector2(r, r), Vector2(s, s)), false)
		return
	if DictIO.str_of(_record, "kind") == "vael":
		_vael(c, r)
		return
	var skin: Color = Color(DictIO.str_of(_record, "skin", "#B07A55"))
	var hair: Color = Color(DictIO.str_of(_record, "hair", "#2B211C"))
	var collar: Color = Tokens.color(DictIO.str_of(_record, "collar", "accent.teal"))
	# Shoulders and collar.
	_shoulders(c, r, collar.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.3), c + Vector2(0, r * 0.62), c + Vector2(r * 0.3, r * 0.3)]), collar)
	# Neck and head.
	draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.05), Vector2(r * 0.24, r * 0.3)), skin.darkened(0.12))
	var head: Vector2 = c + Vector2(0, -r * 0.18)
	var tilt: float = {"worried": -0.06, "stern": 0.0, "warm": 0.05}.get(expression, 0.0)
	head.x += r * tilt
	draw_circle(head, r * 0.34, skin, true, -1.0, true)
	_hair(DictIO.str_of(_record, "hair_style", "short"), head, r, hair)
	# Eyes and mouth hint at the expression.
	var eye_y: float = head.y - r * 0.02
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(head.x + side * r * 0.12, eye_y), r * 0.03, Tokens.color("bg.deep"), true, -1.0, true)
	var mouth_y: float = head.y + r * 0.16
	match expression:
		"warm":
			draw_arc(Vector2(head.x, mouth_y - r * 0.04), r * 0.1, 0.2, PI - 0.2, 12, Tokens.color("bg.deep"), 2.0, true)
		"worried":
			draw_arc(Vector2(head.x, mouth_y + r * 0.05), r * 0.08, PI + 0.4, TAU - 0.4, 12, Tokens.color("bg.deep"), 2.0, true)
		_:
			draw_line(Vector2(head.x - r * 0.08, mouth_y), Vector2(head.x + r * 0.08, mouth_y), Tokens.color("bg.deep"), 2.0, true)
	match DictIO.str_of(_record, "accessory", "none"):
		"glasses":
			for side2: float in [-1.0, 1.0]:
				draw_arc(Vector2(head.x + side2 * r * 0.12, eye_y), r * 0.075, 0, TAU, 16, Tokens.color("text.primary"), 1.5, true)
		"badge", "pin":
			draw_circle(c + Vector2(r * 0.32, r * 0.55), r * 0.06, Tokens.color("hearth.gold"), true, -1.0, true)
		"plate":
			draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.35), Vector2(r * 0.4, r * 0.25)), Tokens.color("mineral.slate"))


## The shoulders: the top of a circle below the head, cut to the disc so nothing spills out.
func _shoulders(c: Vector2, r: float, col: Color) -> void:
	var sc: Vector2 = c + Vector2(0, r * 1.05)
	var sr: float = r * 0.78
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 49:
		var a: float = PI + PI * i / 48.0
		var p: Vector2 = sc + Vector2(cos(a), sin(a)) * sr
		if p.distance_to(c) <= r:
			pts.append(p)
	if pts.size() < 2:
		return
	# Back along the rim of the disc, from the right shoulder round the bottom to the left one.
	var a_right: float = (pts[pts.size() - 1] - c).angle()
	var a_left: float = (pts[0] - c).angle()
	if a_left < a_right:
		a_left += TAU
	for i in 17:
		var a2: float = lerpf(a_right, a_left, i / 16.0)
		pts.append(c + Vector2(cos(a2), sin(a2)) * r)
	draw_colored_polygon(pts, col)


func _hair(style: String, head: Vector2, r: float, hair: Color) -> void:
	match style:
		"bald":
			return
		"bun":
			draw_circle(head + Vector2(0, -r * 0.36), r * 0.14, hair, true, -1.0, true)
			draw_arc(head, r * 0.34, PI, TAU, 24, hair, r * 0.1, true)
		"long":
			draw_arc(head, r * 0.36, PI * 0.9, TAU + PI * 0.1, 24, hair, r * 0.14, true)
		"shaved_side":
			draw_arc(head, r * 0.34, PI * 1.2, TAU, 18, hair, r * 0.12, true)
		_:
			draw_arc(head, r * 0.33, PI, TAU, 24, hair, r * 0.09, true)


func _vael(c: Vector2, r: float) -> void:
	var col: Color = Tokens.color("other.magenta")
	var bright: float = {"warm": 1.0, "worried": 0.45, "stern": 0.9}.get(expression, 0.7)
	var spread: float = {"warm": 0.62, "worried": 0.4, "stern": 0.5}.get(expression, 0.55)
	for i in 7:
		var a: float = i * TAU / 7.0 + i * 0.35
		var d: float = r * spread * (0.35 + i * 0.1)
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * d
		draw_circle(p, r * 0.12, Color(col, 0.2 * bright), true, -1.0, true)
		draw_circle(p, r * 0.05, Color(col.lightened(0.3), bright), true, -1.0, true)
