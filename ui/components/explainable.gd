class_name Explainable
extends MarginContainer
## Wraps any number, icon or status so its Breakdown can always be opened (§6.1):
##   PC     hover 300 ms opens, click pins, click again unpins
##   touch  tap opens (numbers), long-press opens anything
##   keys   focus it and press Enter
## Nested breakdowns open from the tooltip's own lines, up to two levels. The UI shows the
## Breakdown the simulation emitted; it never recomputes it.

signal opened

var breakdown: Breakdown = null
## Numbers open on a tap; icons and statuses only on long-press (so taps can do other things).
var tap_opens: bool = true
## 1 for things on screens; 2 for lines inside a level-1 tooltip.
var level: int = 1

var _hover_timer: Timer
var _long_timer: Timer
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _long_fired: bool = false
var _hovered: bool = false


static func wrap(content: Control, b: Breakdown, p_tap_opens: bool = true) -> Explainable:
	var e: Explainable = Explainable.new()
	e.breakdown = b
	e.tap_opens = p_tap_opens
	e.add_child(content)
	return e


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_HELP
	for side: String in ["margin_left", "margin_right"]:
		add_theme_constant_override(side, 2)
	add_to_group("explainable")


func _ready() -> void:
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = Tokens.HOVER_DELAY
	_hover_timer.timeout.connect(_open.bind(false))
	add_child(_hover_timer)
	_long_timer = Timer.new()
	_long_timer.one_shot = true
	_long_timer.wait_time = Tokens.LONG_PRESS
	_long_timer.timeout.connect(_on_long_press)
	add_child(_long_timer)
	for c: Node in get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Layout.changed.connect(_fit_target)
	_fit_target()


## On touch layouts every explainable thing is at least one touch target in size.
func _fit_target() -> void:
	var t: float = Layout.target_size() if Layout.touch_ui else 0.0
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, t), maxf(custom_minimum_size.y, t))


func set_breakdown(b: Breakdown) -> void:
	breakdown = b


## Opens the breakdown pinned (used by keyboard, tests and the screenshot tour).
func open_pinned() -> BreakdownTooltip:
	return _open(true)


func _open(pinned: bool) -> BreakdownTooltip:
	if breakdown == null:
		return null
	var tip: BreakdownTooltip = Overlay.show_breakdown(self, breakdown, level, pinned)
	queue_redraw()
	opened.emit()
	return tip


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_long_fired = false
			_press_pos = mb.position
			if Layout.touch_ui:
				_long_timer.start()
			accept_event()
		elif _pressing:
			_pressing = false
			_long_timer.stop()
			if _long_fired:
				accept_event()
				return
			if Layout.touch_ui:
				if tap_opens:
					_toggle()
			else:
				_toggle()
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if (event as InputEventMouseMotion).position.distance_to(_press_pos) > 12.0:
			_pressing = false
			_long_timer.stop()
	elif event.is_action_pressed("ui_accept"):
		_toggle()
		accept_event()


func _toggle() -> void:
	if Overlay.is_pinned(self):
		Overlay.close_breakdowns(level)
	else:
		_open(true)


func _on_long_press() -> void:
	if _pressing:
		_long_fired = true
		_open(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			queue_redraw()
			if not Layout.touch_ui:
				Overlay.cancel_close()
				if not Overlay.is_open(self):
					_hover_timer.start()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			queue_redraw()
			_hover_timer.stop()
			if not Layout.touch_ui:
				Overlay.request_close()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
			queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if _hovered or Overlay.is_open(self):
		var bg: StyleBoxFlat = StyleBoxFlat.new()
		bg.bg_color = Color(Tokens.color("bg.panel.alt"), 0.9)
		bg.set_corner_radius_all(Tokens.RADIUS_CHIP)
		draw_style_box(bg, r)
	if has_focus():
		var f: StyleBoxFlat = StyleBoxFlat.new()
		f.draw_center = false
		f.set_border_width_all(2)
		f.border_color = Tokens.color("hearth.gold")
		f.set_corner_radius_all(Tokens.RADIUS_CHIP)
		draw_style_box(f, r)
