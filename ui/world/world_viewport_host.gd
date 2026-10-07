class_name WorldViewportHost
extends Control
## A persistent screen child. Layouts supply disposable mount rectangles; the host
## clips to the scroll region without reparenting or exiting its renderer's tree.
signal selected(id: String)
signal presentation_failed
var renderer: Control
var mount: WeakRef
var session: VisualSession
var scheduler: GenerationScheduler
var cache: VisualResourceCache
var camera_key: String = ""
var _screen: WeakRef
var _scene_epoch: int = -1

func setup(screen: Control, visual_session: VisualSession, generation: GenerationScheduler, resources: VisualResourceCache) -> void:
	_screen = weakref(screen)
	session = visual_session; scheduler = generation; cache = resources
	name = "WorldViewportHost"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	if not Settings.changed.is_connected(_on_setting): Settings.changed.connect(_on_setting)

func attach(placeholder: Control, description: Dictionary, preview: Dictionary = {}) -> void:
	var key: String = str(description.get("view_kind", "")) + ":" + str(description.get("id", ""))
	if description.is_empty() or not description.get("appearance_supported", true) or int(description.get("session_epoch", -1)) != session.epoch:
		fail_presentation()
		return
	if key != camera_key or _scene_epoch != session.epoch:
		deactivate()
		camera_key = key
		_scene_epoch = session.epoch
		if description["view_kind"] == "system":
			var system_renderer: M1SystemRenderer = M1SystemRenderer.new()
			system_renderer.bind_services(scheduler, cache, session.epoch, str(get_instance_id()))
			if Settings.visual_quality == "low" or (Settings.visual_quality == "auto" and (OS.has_feature("web") or Layout.compact)):
				system_renderer.render_scale_divisor = 2
				system_renderer.overview_width = 128
				system_renderer.focus_width = 512
			renderer = system_renderer
		elif description["view_kind"] == "galaxy":
			var galaxy_renderer: GalaxyRenderer = GalaxyRenderer.new()
			galaxy_renderer.bind_services(scheduler, cache, session.epoch, str(get_instance_id()))
			galaxy_renderer.overview_width = 64
			galaxy_renderer.focus_width = 256
			galaxy_renderer.render_scale_divisor = 2 if OS.has_feature("web") or Settings.visual_quality == "low" else 1
			renderer = galaxy_renderer
		elif description["view_kind"] == "colony":
			var city_renderer: ColonyRenderer = ColonyRenderer.new()
			city_renderer.bind_services(scheduler,cache,session.epoch,str(get_instance_id()))
			city_renderer.render_scale_divisor = 2 if Settings.visual_quality == "low" or (Settings.visual_quality == "auto" and (OS.has_feature("web") or Layout.compact)) else 1
			renderer=city_renderer
		else:
			fail_presentation()
			return
		renderer.name = "WorldRenderer"
		if description["view_kind"] == "colony":
			renderer.connect("selected",func(index: int) -> void: selected.emit("slot:"+str(index)))
			renderer.connect("overview_requested",func() -> void: selected.emit(""))
		else: renderer.connect("selected", func(id: String) -> void: selected.emit(id))
		if description["view_kind"] == "colony": renderer.call("configure",description,preview)
		else: renderer.call("configure",description)
		add_child(renderer)
		_apply_renderer_quality()
		_apply_renderer_graphics()
		call_deferred("_apply_renderer_graphics")
		renderer.call("restore_camera", session.recall(camera_key))
	else:
		if description["view_kind"] == "colony": renderer.call("configure",description,preview)
		else: renderer.call("configure",description)
		_apply_renderer_graphics()
	mount = weakref(placeholder)

func deactivate() -> void:
	if is_instance_valid(renderer):
		if _scene_epoch == session.epoch: session.remember(camera_key, renderer.call("camera_state"))
		scheduler.cancel_owner(str(get_instance_id()))
		cache.release_owner(str(get_instance_id()))
		remove_child(renderer)
		renderer.queue_free()
	renderer = null; mount = null; camera_key = ""
	visible = false

func fail_presentation() -> void:
	deactivate()
	presentation_failed.emit()


func _on_setting(key: String) -> void:
	if key in ["render_scale", "anti_aliasing"]:
		_apply_renderer_graphics()


func _apply_renderer_quality() -> void:
	if not is_instance_valid(renderer): return
	var divisor: int = int(renderer.get("render_scale_divisor"))
	if renderer is M1SystemRenderer:
		divisor = 2 if Settings.visual_quality == "low" or (Settings.visual_quality == "auto" and (OS.has_feature("web") or Layout.compact)) else 1
	elif renderer is GalaxyRenderer:
		divisor = 2 if OS.has_feature("web") or Settings.visual_quality == "low" else 1
	elif renderer is ColonyRenderer:
		divisor = 2 if Settings.visual_quality == "low" or (Settings.visual_quality == "auto" and (OS.has_feature("web") or Layout.compact)) else 1
	renderer.set("render_scale_divisor", divisor)
	var container: Variant = renderer.get("_container")
	if container is SubViewportContainer: container.stretch_shrink = divisor


func _apply_renderer_graphics() -> Dictionary:
	if not is_instance_valid(renderer): return {}
	var viewport: Variant = renderer.get("viewport")
	if not viewport is SubViewport: return {}
	return DisplaySettings.apply_viewport_graphics(viewport, int(renderer.get("render_scale_divisor")))


func graphics_metrics() -> Dictionary:
	var metrics: Dictionary = _apply_renderer_graphics()
	if metrics.is_empty(): return {"mounted": false}
	metrics["mounted"] = true
	return metrics

func _process(_delta: float) -> void:
	var placeholder: Control = mount.get_ref() as Control if mount != null else null
	var screen: Control = _screen.get_ref() as Control
	if not is_instance_valid(placeholder) or not is_instance_valid(screen) or renderer == null:
		visible = false
		return
	var desired: Rect2 = placeholder.get_global_rect()
	var scroll: ScrollContainer = screen.get("_scroll") as ScrollContainer
	var clipped: Rect2 = desired.intersection(scroll.get_global_rect())
	visible = placeholder.is_visible_in_tree() and clipped.size.x > 1 and clipped.size.y > 1
	position = clipped.position - screen.global_position
	size = clipped.size
	renderer.position = desired.position - clipped.position
	renderer.size = desired.size
	var blocked: bool = Overlay.stack_size() > 0
	renderer.call("set_active", visible, blocked)
	scheduler.set_owner_active(str(get_instance_id()), visible)

func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_setting): Settings.changed.disconnect(_on_setting)
	deactivate()
