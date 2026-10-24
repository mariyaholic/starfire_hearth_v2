extends CanvasLayer
## Everything that floats above screens: breakdown tooltips (two levels), toasts, modals, drawers
## and bottom sheets. One host keeps stacking, dismissal (Esc, back, tap outside) and the id audit
## simple: overlays are always children of `root`.

const MAX_LEVELS: int = 2
const CLOSE_GRACE: float = 0.25
const MAX_TOASTS: int = 3

## Full-window container for every overlay.
var root: Control
var _toast_box: VBoxContainer
var _tips: Array[Dictionary] = []
var _stack: Array[Control] = []
var _close_timer: Timer


func _ready() -> void:
	layer = 50
	root = Control.new()
	root.name = "OverlayRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_toast_box = VBoxContainer.new()
	_toast_box.name = "Toasts"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(_toast_box)
	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.wait_time = CLOSE_GRACE
	_close_timer.timeout.connect(_close_unpinned_if_idle)
	add_child(_close_timer)
	Layout.changed.connect(_relayout)
	Layout.theme_rebuilt.connect(_apply_theme)
	_apply_theme()
	_relayout()


## Controls under a CanvasLayer do not inherit the window's theme, so the overlay root carries it.
func _apply_theme() -> void:
	root.theme = Layout.theme


# --- breakdown tooltips -----------------------------------------------------------------------

## Opens the breakdown of `anchor` at `level` (1 or 2). Opening level 1 closes everything open.
func show_breakdown(anchor: Control, b: Breakdown, level: int, pinned: bool) -> BreakdownTooltip:
	if b == null or level < 1 or level > MAX_LEVELS:
		return null
	for i in range(_tips.size() - 1, -1, -1):
		if int(_tips[i]["level"]) >= level:
			(_tips[i]["panel"] as Control).queue_free()
			_tips.remove_at(i)
	var tip: BreakdownTooltip = BreakdownTooltip.new()
	tip.setup(b, level)
	tip.pinned = pinned
	if pinned:
		Audio.play("ui_tooltip_pin")
	root.add_child(tip)
	_tips.append({"level": level, "panel": tip, "anchor": anchor})
	tip.mouse_entered.connect(_close_timer.stop)
	tip.mouse_exited.connect(request_close)
	tip.resized.connect(_place_tip.bind(tip, anchor))
	_place_tip.call_deferred(tip, anchor)
	return tip


func is_open(anchor: Control) -> bool:
	for t: Dictionary in _tips:
		if t["anchor"] == anchor:
			return true
	return false


func is_pinned(anchor: Control) -> bool:
	for t: Dictionary in _tips:
		if t["anchor"] == anchor:
			return (t["panel"] as BreakdownTooltip).pinned
	return false


func close_breakdowns(from_level: int = 1) -> void:
	for i in range(_tips.size() - 1, -1, -1):
		if int(_tips[i]["level"]) >= from_level:
			(_tips[i]["panel"] as Control).queue_free()
			_tips.remove_at(i)


## Hover left an anchor or tooltip: close unpinned tooltips unless the pointer comes back soon.
func request_close() -> void:
	_close_timer.start()


func cancel_close() -> void:
	_close_timer.stop()


func open_tooltips() -> Array[BreakdownTooltip]:
	var out: Array[BreakdownTooltip] = []
	for t: Dictionary in _tips:
		out.append(t["panel"])
	return out


func _close_unpinned_if_idle() -> void:
	var mouse: Vector2 = root.get_global_mouse_position()
	for i in range(_tips.size() - 1, -1, -1):
		var tip: BreakdownTooltip = _tips[i]["panel"]
		var anchor: Control = _tips[i]["anchor"]
		if tip.pinned:
			continue
		if tip.get_global_rect().has_point(mouse):
			continue
		if is_instance_valid(anchor) and anchor.get_global_rect().has_point(mouse):
			continue
		tip.queue_free()
		_tips.remove_at(i)


func _place_tip(tip: BreakdownTooltip, anchor: Control) -> void:
	if not is_instance_valid(tip) or not is_instance_valid(anchor):
		return
	var m: Vector4 = Layout.safe_margins
	var margin: float = Tokens.SPACE_S
	var view: Rect2 = Rect2(Vector2(m.x, m.y), root.size - Vector2(m.x + m.z, m.y + m.w)).grow(-margin)
	tip.fit(view.size.y)
	tip.reset_size()
	var s: Vector2 = tip.size
	var a: Rect2 = anchor.get_global_rect()
	var pos: Vector2
	if Layout.compact:
		# Phones: centred sideways, below the anchor if it fits, else above, else as high as it
		# can go; a nested breakdown cascades over its parent.
		pos.x = view.position.x + (view.size.x - s.x) / 2.0
		pos.y = a.end.y + Tokens.SPACE_XS
		if pos.y + s.y > view.end.y:
			pos.y = a.position.y - s.y - Tokens.SPACE_XS
		if pos.y < view.position.y:
			pos.y = view.position.y
		if tip.level > 1:
			pos += Vector2(Tokens.SPACE_L, Tokens.SPACE_L)
	elif tip.level > 1 and _parent_tip_rect(tip.level) != Rect2():
		# PC: a nested breakdown opens beside its parent, level with the line that opened it.
		var parent: Rect2 = _parent_tip_rect(tip.level)
		pos = Vector2(parent.end.x + Tokens.SPACE_S, a.position.y - Tokens.SPACE_S)
		if pos.x + s.x > view.end.x:
			pos.x = parent.position.x - s.x - Tokens.SPACE_S
	else:
		pos = Vector2(a.position.x, a.end.y + Tokens.SPACE_XS)
		if pos.y + s.y > view.end.y:
			pos.y = a.position.y - s.y - Tokens.SPACE_XS
		if pos.y < view.position.y:
			pos.y = clampf(a.end.y + Tokens.SPACE_XS, view.position.y, maxf(view.position.y, view.end.y - s.y))
			pos.x = a.end.x + Tokens.SPACE_S
			if pos.x + s.x > view.end.x:
				pos.x = a.position.x - s.x - Tokens.SPACE_S
	pos.x = clampf(pos.x, view.position.x, maxf(view.position.x, view.end.x - s.x))
	pos.y = clampf(pos.y, view.position.y, maxf(view.position.y, view.end.y - s.y))
	tip.position = pos


func _parent_tip_rect(level: int) -> Rect2:
	for t: Dictionary in _tips:
		if int(t["level"]) == level - 1:
			return (t["panel"] as Control).get_global_rect()
	return Rect2()


# --- modal stack: modals, drawers, sheets -----------------------------------------------------

## Shows a full-window overlay (Modal, Drawer, BottomSheet). The newest one receives Esc/back.
func push(layer_control: Control) -> void:
	close_breakdowns()
	root.add_child(layer_control)
	root.move_child(_toast_box, -1)
	_stack.append(layer_control)
	layer_control.tree_exiting.connect(_forget.bind(layer_control))


## Closes every overlay at once (screen changes, the screenshot tour).
func close_all() -> void:
	close_breakdowns()
	clear_toasts()
	for c: Control in _stack.duplicate():
		c.queue_free()
	_stack.clear()


func top() -> Control:
	return _stack[_stack.size() - 1] if not _stack.is_empty() else null


func stack_size() -> int:
	return _stack.size()


func _forget(c: Control) -> void:
	_stack.erase(c)


# --- toasts -----------------------------------------------------------------------------------

func toast(text: String, severity: String = ReportItem.SEVERITY_INFO, seconds: float = 4.0) -> Toast:
	var t: Toast = Toast.new()
	t.setup(text, severity)
	if severity == ReportItem.SEVERITY_WARNING:
		Audio.play("ui_alert")
	elif severity == ReportItem.SEVERITY_CRITICAL:
		Audio.play("ui_alert_critical")
	_toast_box.add_child(t)
	while _toast_box.get_child_count() > MAX_TOASTS:
		var oldest: Node = _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()
	if seconds > 0.0:
		get_tree().create_timer(seconds).timeout.connect(t.dismiss)
	return t


func clear_toasts() -> void:
	for c: Node in _toast_box.get_children():
		c.queue_free()


# --- input and layout -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not _tips.is_empty():
			close_breakdowns(_tips[_tips.size() - 1]["level"])
			get_viewport().set_input_as_handled()
		elif not _stack.is_empty() and top().has_method("dismiss"):
			top().call("dismiss")
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not _tips.is_empty():
		var p: Vector2 = root.get_global_mouse_position()
		for t: Dictionary in _tips:
			if (t["panel"] as Control).get_global_rect().has_point(p):
				return
		close_breakdowns()


## Toasts sit bottom-centre on phones and bottom-right on PC, growing upward.
func _relayout() -> void:
	if root == null:
		return
	var m: Vector4 = Layout.safe_margins
	var w: float = 420.0 if not Layout.compact else minf(420.0, Layout.logical_size.x - 32.0 - m.x - m.z)
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.anchor_top = 1.0
	_toast_box.anchor_bottom = 1.0
	if Layout.compact:
		_toast_box.anchor_left = 0.5
		_toast_box.anchor_right = 0.5
		_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast_box.offset_left = -w / 2.0 + (m.x - m.z) / 2.0
		_toast_box.offset_right = w / 2.0 + (m.x - m.z) / 2.0
		_toast_box.offset_bottom = -(16.0 + m.w)
	else:
		_toast_box.anchor_left = 1.0
		_toast_box.anchor_right = 1.0
		_toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_toast_box.offset_right = -(24.0 + m.z)
		_toast_box.offset_left = _toast_box.offset_right - w
		_toast_box.offset_bottom = -96.0
	_toast_box.offset_top = _toast_box.offset_bottom
