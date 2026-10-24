class_name DisplaySettingsService
extends Node
## Native display operations and capability gates (§3). Settings remains the
## persisted source of truth; this service applies only operations supported by
## the active backend and keeps risky window changes reversible.

signal changed(key: String)
signal preview_changed(state: Dictionary)

const PREVIEW_SECONDS: float = 8.0
const MIN_REACHABLE_PIXELS: int = 64

var _capabilities: Dictionary = {}
var _preview_before: Dictionary = {}
var _preview_target: Dictionary = {}
var _preview_deadline_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_capabilities()
	Settings.changed.connect(_on_setting)
	if get_window() != null:
		get_window().focus_exited.connect(_on_focus_exited)
	_apply_graphics_settings()
	_apply_saved_window()


func _process(_delta: float) -> void:
	if not _preview_target.is_empty() and _preview_deadline_msec > 0 and Time.get_ticks_msec() >= _preview_deadline_msec:
		revert_preview()
	elif not _preview_target.is_empty():
		preview_changed.emit(preview_state())
	else:
		_capture_windowed_geometry()


func _exit_tree() -> void:
	if not _preview_target.is_empty(): revert_preview()


func refresh_capabilities() -> Dictionary:
	var web: bool = OS.has_feature("web")
	var headless: bool = DisplayServer.get_name() == "headless"
	var native_window: bool = not web and not headless
	var exclusive: bool = native_window and OS.has_feature("windows")
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var render_scale_supported: bool = not headless and renderer not in ["gl_compatibility", ""]
	_capabilities = {
		"web": web,
		"headless": headless,
		"native_window": native_window,
		"window_modes": (["windowed", "borderless", "fullscreen", "exclusive_fullscreen"] if exclusive else ["windowed", "borderless", "fullscreen"]) if native_window else [],
		"monitor_selection": native_window,
		"arbitrary_window_size": native_window,
		"browser_fullscreen": _browser_fullscreen_supported() if web else false,
		"render_scale": render_scale_supported,
		"render_scale_reason": "renderer_scaling_3d_unavailable" if not render_scale_supported else "supported",
		"vsync": native_window,
		"frame_cap": not headless,
		"anti_aliasing": not headless,
		# Platform detection is useful for selecting backend APIs, but it is never
		# evidence that the required physical Windows gate has been exercised.
		"windows_platform": OS.has_feature("windows"),
		"windows_runtime": "unverified",
	}
	return capabilities()


func capabilities() -> Dictionary:
	return _capabilities.duplicate(true)


func supports(key: String) -> bool:
	return bool(_capabilities.get(key, false))


func supported_window_modes() -> Array[String]:
	var modes: Variant = _capabilities.get("window_modes", [])
	var out: Array[String] = []
	if modes is Array:
		for mode: Variant in modes: out.append(str(mode))
	return out


func monitor_count() -> int:
	return DisplayServer.get_screen_count() if supports("monitor_selection") else 0


func window_size_presets() -> Dictionary:
	return {
		"small": Vector2i(1280, 720),
		"standard": Vector2i(1600, 900),
		"large": Vector2i(1920, 1080),
	}


func current_window_state() -> Dictionary:
	if not supports("native_window"):
		return {"supported": false, "mode": "browser", "monitor": 0, "size": Vector2i.ZERO,
			"position": Vector2i.ZERO, "maximized": false}
	var mode: int = int(DisplayServer.window_get_mode())
	var mode_name: String = "windowed"
	match mode:
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			mode_name = "windowed"
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			mode_name = "fullscreen"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			mode_name = "exclusive_fullscreen"
		_:
			mode_name = "borderless" if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) else "windowed"
	return {"supported": true, "mode": mode_name,
		"monitor": maxi(0, DisplayServer.window_get_current_screen()),
		"size": DisplayServer.window_get_size(), "position": DisplayServer.window_get_position(),
		"maximized": mode == DisplayServer.WINDOW_MODE_MAXIMIZED}


## Preview a native mode/monitor/size change. The old rectangle is restored
## automatically if the user does not call keep_preview before the deadline.
func preview_window(request: Dictionary, timeout_seconds: float = PREVIEW_SECONDS) -> Dictionary:
	if not supports("native_window"):
		return {"ok": false, "reason": "unsupported_backend", "state": preview_state()}
	var target: Dictionary = _normalize_window_request(request)
	if target.is_empty():
		return {"ok": false, "reason": "invalid_request", "state": preview_state()}
	if _preview_target.is_empty(): _preview_before = current_window_state()
	_preview_target = target
	_apply_window_state(target)
	_preview_deadline_msec = Time.get_ticks_msec() + maxi(1, roundi(timeout_seconds * 1000.0))
	var state: Dictionary = preview_state()
	preview_changed.emit(state)
	return {"ok": true, "reason": "preview", "state": state}


func preview_state() -> Dictionary:
	if _preview_target.is_empty(): return {"active": false, "remaining_seconds": 0, "target": {}}
	var remaining: int = maxi(0, ceili(float(_preview_deadline_msec - Time.get_ticks_msec()) / 1000.0))
	return {"active": true, "remaining_seconds": remaining, "target": _preview_target.duplicate(true)}


func keep_preview() -> bool:
	if _preview_target.is_empty(): return false
	var target: Dictionary = _preview_target.duplicate(true)
	var before: Dictionary = _preview_before
	var saved_size: Vector2i = before.get("size", Settings.window_size())
	var saved_position: Vector2i = before.get("position", Vector2i(Settings.window_x, Settings.window_y))
	# Fullscreen and borderless replace the visible rectangle; retain the last
	# windowed rectangle so restoring later does not shrink to the monitor or
	# lose the user's custom position.
	if str(target.get("mode", "windowed")) == "windowed":
		saved_size = target.get("size", saved_size)
		saved_position = target.get("position", saved_position)
	Settings.set_window_state(str(target.get("mode", "windowed")), int(target.get("monitor", 0)), saved_size, bool(target.get("maximized", false)), saved_position)
	_clear_preview()
	return true


func revert_preview() -> bool:
	if _preview_target.is_empty(): return false
	_apply_window_state(_preview_before)
	_clear_preview()
	return true


func request_browser_fullscreen() -> bool:
	if not supports("browser_fullscreen"): return false
	var result: Variant = JavaScriptBridge.eval("(() => { try { const e=document.documentElement; if (!e.requestFullscreen) return false; e.requestFullscreen(); return true; } catch (_) { return false; } })()", true)
	return bool(result)


func _clear_preview() -> void:
	_preview_before = {}
	_preview_target = {}
	_preview_deadline_msec = 0
	preview_changed.emit(preview_state())


func _normalize_window_request(request: Dictionary) -> Dictionary:
	var mode: String = str(request.get("mode", Settings.window_mode))
	if mode not in supported_window_modes(): return {}
	var monitor: int = clampi(int(request.get("monitor", Settings.window_monitor)), 0, maxi(0, DisplayServer.get_screen_count() - 1))
	var size: Vector2i = request.get("size", Settings.window_size())
	if not size is Vector2i: size = Settings.window_size()
	size = Vector2i(clampi(size.x, Settings.WINDOW_WIDTH_MIN, Settings.WINDOW_WIDTH_MAX), clampi(size.y, Settings.WINDOW_HEIGHT_MIN, Settings.WINDOW_HEIGHT_MAX))
	var current: Dictionary = current_window_state()
	var position: Variant = request.get("position", current.get("position", Vector2i(Settings.window_x, Settings.window_y)))
	if not request.has("position") and current.get("mode", "windowed") != "windowed": position = Vector2i(Settings.window_x, Settings.window_y)
	if not position is Vector2i: position = Vector2i(Settings.window_x, Settings.window_y)
	return {"mode": mode, "monitor": monitor, "size": size, "position": position,
		"maximized": bool(request.get("maximized", Settings.window_maximized))}


func _apply_window_state(state: Dictionary) -> void:
	if not supports("native_window") or state.is_empty(): return
	var monitor: int = clampi(int(state.get("monitor", 0)), 0, maxi(0, DisplayServer.get_screen_count() - 1))
	var size: Vector2i = state.get("size", Settings.window_size())
	if not size is Vector2i: size = Settings.window_size()
	var mode: String = str(state.get("mode", "windowed"))
	if mode == "exclusive_fullscreen" and "exclusive_fullscreen" not in supported_window_modes(): mode = "windowed"
	# Set a safe windowed rectangle before a mode switch. This prevents an old
	# off-screen rectangle from becoming the only recovery path.
	DisplayServer.window_set_current_screen(monitor)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var position: Variant = state.get("position", null)
	if mode == "borderless":
		# Borderless means the full reachable rectangle of the selected monitor,
		# while Settings.window_* continues to hold the restore rectangle.
		var desktop: Rect2i = Rect2i(DisplayServer.screen_get_position(monitor), DisplayServer.screen_get_size(monitor))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_size(desktop.size)
		DisplayServer.window_set_position(desktop.position)
	elif mode == "fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == "exclusive_fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(size)
		if position is Vector2i: DisplayServer.window_set_position(position)
		if bool(state.get("maximized", false)): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _apply_saved_window() -> void:
	if not supports("native_window"): return
	var screen: int = clampi(Settings.window_monitor, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	var size: Vector2i = Settings.window_size()
	var position: Vector2i = Vector2i(Settings.window_x, Settings.window_y)
	var mode: String = Settings.window_mode if Settings.window_mode in supported_window_modes() else "windowed"
	if mode != Settings.window_mode: Settings.set_window_mode(mode)
	var desktop: Rect2i = Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	if position.x <= -100000 or position.y <= -100000 or not Rect2i(position, size).intersects(desktop.grow(-MIN_REACHABLE_PIXELS)):
		position = desktop.position + Vector2i(maxi(0, (desktop.size.x - size.x) / 2), maxi(0, (desktop.size.y - size.y) / 2))
	_apply_window_state({"mode":mode, "monitor":screen, "size":size, "position":position, "maximized":Settings.window_maximized})


func _apply_graphics_settings() -> void:
	if supports("frame_cap"): Engine.max_fps = Settings.frame_cap
	if supports("vsync"):
		DisplayServer.window_set_vsync_mode(_vsync_value(Settings.vsync_mode))
	if supports("render_scale"):
		var viewport: Viewport = get_viewport()
		if viewport != null: viewport.scaling_3d_scale = Settings.render_scale
	if supports("anti_aliasing"):
		var root_viewport: Viewport = get_viewport()
		if root_viewport != null: root_viewport.msaa_3d = _aa_value(Settings.anti_aliasing)


## Apply the same user graphics choices to a production world SubViewport. The
## quality divisor remains the renderer's pixel-budget control; UI scaling never
## enters this path.
func apply_viewport_graphics(viewport: SubViewport, quality_divisor: int = 1) -> Dictionary:
	if viewport == null: return {}
	var divisor: int = maxi(1, quality_divisor)
	var actual_scale: float = 1.0
	if supports("render_scale"):
		viewport.scaling_3d_scale = Settings.render_scale
		actual_scale = Settings.render_scale
	if supports("anti_aliasing"): viewport.msaa_3d = _aa_value(Settings.anti_aliasing)
	return {"viewport_size": viewport.size, "msaa": int(viewport.msaa_3d),
		"render_scale": actual_scale, "quality_divisor": divisor,
		"effective_pixel_ratio": actual_scale / float(divisor)}


func _on_setting(key: String) -> void:
	if key in ["frame_cap", "vsync_mode", "render_scale", "anti_aliasing"]:
		_apply_graphics_settings()
		changed.emit(key)
	elif key in ["window_mode", "window_monitor", "window_width", "window_height", "window_maximized"] and _preview_target.is_empty():
		_apply_saved_window()
		changed.emit(key)


func _capture_windowed_geometry() -> void:
	if not supports("native_window"): return
	var state: Dictionary = current_window_state()
	if state.get("mode") != "windowed" or bool(state.get("maximized", false)): return
	var size: Vector2i = state.get("size", Settings.window_size())
	var position: Vector2i = state.get("position", Vector2i(Settings.window_x, Settings.window_y))
	if size != Settings.window_size(): Settings.set_window_size(size)
	if position != Vector2i(Settings.window_x, Settings.window_y): Settings.set_window_position(position)


func _on_focus_exited() -> void:
	if not _preview_target.is_empty(): revert_preview()


func _vsync_value(mode: String) -> int:
	match mode:
		"disabled": return DisplayServer.VSYNC_DISABLED
		"adaptive": return DisplayServer.VSYNC_ADAPTIVE
		"mailbox": return DisplayServer.VSYNC_MAILBOX
		_: return DisplayServer.VSYNC_ENABLED


func _aa_value(mode: String) -> int:
	match mode:
		"2x": return Viewport.MSAA_2X
		"4x": return Viewport.MSAA_4X
		"8x": return Viewport.MSAA_8X
		_: return Viewport.MSAA_DISABLED


func _browser_fullscreen_supported() -> bool:
	if not OS.has_feature("web"): return false
	var supported: Variant = JavaScriptBridge.eval("typeof document !== 'undefined' && !!document.fullscreenEnabled && !!document.documentElement.requestFullscreen", true)
	return bool(supported)
