class_name HighlightRing
extends Control
## A pulsing outline around the control the advisor is talking about (§6.4). It follows its
## target every frame, so it stays put through scrolling and layout changes, and it holds still
## when Reduce Motion is on.

var target: Control = null:
	set(v):
		target = v
		visible = target != null
		set_process(target != null)
		queue_redraw()


func _init() -> void:
	name = "HighlightRing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		visible = false
		return
	visible = true
	var r: Rect2 = target.get_global_rect().grow(4.0)
	global_position = r.position
	size = r.size
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 if Settings.reduce_motion else 0.65 + 0.35 * sin(Time.get_ticks_msec() / 250.0)
	var col: Color = Tokens.color("hearth.gold")
	col.a = pulse
	draw_rect(Rect2(Vector2.ZERO, size), col, false, 3.0)
