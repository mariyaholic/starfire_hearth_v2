extends RefCounted

class SystemProbe extends M1SystemRenderer:
	var selections: int = 0
	func _ready() -> void:
		_container = SubViewportContainer.new()
		add_child(_container)
		viewport = SubViewport.new()
		_container.add_child(viewport)
	# The input fixture deliberately does not construct a camera or scene.
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass
	func pick_body(_position: Vector2) -> String: return "test"
	func focus_body(_id: String, _emit_selection: bool = true) -> void: selections += 1

class ColonyProbe extends ColonyRenderer:
	var selections: int = 0
	func _ready() -> void:
		_container = SubViewportContainer.new()
		add_child(_container)
		viewport = SubViewport.new()
		_container.add_child(viewport)
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass
	func pick_slot(_position: Vector2) -> int: return 0
	func select_slot(_index: int, _emit_selection: bool = true) -> void: selections += 1

func _mouse(pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = 0
	return event

func test_cancelled_pointer_does_not_select_after_overlay_or_hidden_view(t: T) -> void:
	for renderer: Control in [SystemProbe.new(), ColonyProbe.new()]:
		Engine.get_main_loop().root.add_child(renderer)
		renderer.call("set_active", true, false)
		renderer.call("_viewport_input", _mouse(true))
		renderer.call("set_active", true, true)
		renderer.call("set_active", true, false)
		renderer.call("_viewport_input", _mouse(false))
		t.eq(renderer.get("selections"), 0, "release after overlay cancels the gesture")
		renderer.call("_viewport_input", _mouse(true))
		renderer.call("set_active", false, false)
		renderer.call("set_active", true, false)
		renderer.call("_viewport_input", _mouse(false))
		t.eq(renderer.get("selections"), 0, "release after hiding cancels the gesture")
		renderer.call("_viewport_input", _mouse(true))
		renderer.call("_viewport_input", _mouse(false))
		t.eq(renderer.get("selections"), 1, "an uninterrupted click still selects")
		# Run a frame while the fixture is active to verify its lifecycle is safe.
		await Engine.get_main_loop().process_frame
		renderer.queue_free()
	await Engine.get_main_loop().process_frame
