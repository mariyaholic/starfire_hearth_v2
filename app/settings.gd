extends Node
## Player settings (§6.9, §7 screen 13), saved to user://settings.cfg.
## Screens read these and listen to `changed`; nothing here touches simulation state.

signal changed(key: String)

const PATH: String = "user://settings.cfg"
const WEB_VIEW_MODE_KEY: String = "starfire_hearth.view_mode.v1"
const DISPLAY_SETTINGS_VERSION: int = 2
const TEXT_SCALE_MIN: float = 1.0
const TEXT_SCALE_MAX: float = 2.0
const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.5
const RENDER_SCALE_MIN: float = 0.5
const RENDER_SCALE_MAX: float = 1.0
const WINDOW_WIDTH_MIN: int = 640
const WINDOW_WIDTH_MAX: int = 7680
const WINDOW_HEIGHT_MIN: int = 360
const WINDOW_HEIGHT_MAX: int = 4320
const WINDOW_MODES: Array[String] = ["windowed", "borderless", "fullscreen", "exclusive_fullscreen"]
const VSYNC_MODES: Array[String] = ["disabled", "enabled", "adaptive", "mailbox"]
const FRAME_CAPS: Array[int] = [0, 30, 60, 90, 120, 144, 240]
const ANTI_ALIASING_MODES: Array[String] = ["disabled", "2x", "4x", "8x"]

## Text size multiplier, 100% to 200%. Layouts reflow; they never overlap.
var text_scale: float = 1.0
## User multiplier on top of the automatic UI scale.
var ui_scale: float = 1.0
var reduce_motion: bool = false
var high_contrast: bool = false
var hints_enabled: bool = true
var appearance: String = "3d"
var visual_quality: String = "auto"
## Interface composition is independent of graphics quality and save content.
var view_mode: String = "command"
## Native window preferences are applied by DisplaySettings when that backend supports them.
var window_mode: String = "windowed"
var window_monitor: int = 0
var window_width: int = 1920
var window_height: int = 1080
var window_x: int = -100000
var window_y: int = -100000
var window_maximized: bool = false
## Render scale is independent of the logical window size and UI scale.
var render_scale: float = 1.0
var vsync_mode: String = "enabled"
var frame_cap: int = 0
var anti_aliasing: String = "2x"
var orbit_visible: bool = true
var orbit_opacity: float = 0.72
var interface_finish: String = "frosted"
var interface_opacity: float = 0.82
var interface_blur: float = 8.0
var interface_gloss: float = 0.10
var interface_edge: float = 0.15
## Volumes of the UI, Effects, Voice and Music buses, 0 to 1 (§8.6).
var ui_volume: float = 0.8
var effects_volume: float = 0.8
var voice_volume: float = 0.8
var music_volume: float = 0.7
var muted: bool = false
## When false (tests, the screenshot tour) nothing is written to disk.
var persist: bool = true


func _init() -> void:
	_load()
	if OS.has_feature("web"):
		# user:// sync is asynchronous on Web. A scalar device preference can
		# persist immediately even when the player closes the page at once.
		var saved: Variant=JavaScriptBridge.eval("(() => { try { return localStorage.getItem('"+WEB_VIEW_MODE_KEY+"'); } catch (_) { return null; } })()",true)
		if saved is String and not saved.is_empty(): view_mode=saved if saved in ["command","immersive"] else "command"


func set_text_scale(v: float) -> void:
	_apply("text_scale", clampf(snappedf(v, 0.05), TEXT_SCALE_MIN, TEXT_SCALE_MAX))


func set_ui_scale(v: float) -> void:
	_apply("ui_scale", clampf(snappedf(v, 0.05), UI_SCALE_MIN, UI_SCALE_MAX))


func set_reduce_motion(v: bool) -> void:
	_apply("reduce_motion", v)


func set_high_contrast(v: bool) -> void:
	_apply("high_contrast", v)


func set_hints_enabled(v: bool) -> void:
	_apply("hints_enabled", v)

func set_appearance(v: String) -> void:
	if v in ["3d", "strategic"]: _apply("appearance", v)

func set_visual_quality(v: String) -> void:
	if v in ["auto", "low", "standard"]: _apply("visual_quality", v)

func set_view_mode(v: String) -> void:
	if v in ["command", "immersive"]: _apply("view_mode", v)

func set_window_mode(v: String) -> void:
	if v in WINDOW_MODES: _apply("window_mode", v)

func set_window_monitor(v: int) -> void:
	_apply("window_monitor", maxi(0, v))

func set_window_size(size: Vector2i) -> void:
	_apply("window_width", clampi(size.x, WINDOW_WIDTH_MIN, WINDOW_WIDTH_MAX))
	_apply("window_height", clampi(size.y, WINDOW_HEIGHT_MIN, WINDOW_HEIGHT_MAX))

func set_window_position(position: Vector2i) -> void:
	_apply("window_x", position.x)
	_apply("window_y", position.y)

func set_window_maximized(v: bool) -> void:
	_apply("window_maximized", v)

func set_render_scale(v: float) -> void:
	_apply("render_scale", clampf(snappedf(v, 0.05), RENDER_SCALE_MIN, RENDER_SCALE_MAX))

func set_vsync_mode(v: String) -> void:
	if v in VSYNC_MODES: _apply("vsync_mode", v)

func set_frame_cap(v: int) -> void:
	if v in FRAME_CAPS: _apply("frame_cap", v)

func set_anti_aliasing(v: String) -> void:
	if v in ANTI_ALIASING_MODES: _apply("anti_aliasing", v)

func set_orbit_visible(v: bool) -> void:
	_apply("orbit_visible", v)

func set_orbit_opacity(v: float) -> void:
	_apply("orbit_opacity", clampf(snappedf(v, 0.05), 0.0, 1.0))

func set_interface_finish(v: String) -> void:
	if v not in ["matte", "frosted", "glossy"]: return
	var repeated: bool=interface_finish==v
	var preset: Array = {"matte":[1.0,0.0,0.0,0.0],"frosted":[0.82,8.0,0.10,0.15],"glossy":[0.75,4.0,0.25,0.25]}[v]
	set_interface_opacity(preset[0]); set_interface_blur(preset[1])
	set_interface_gloss(preset[2]); set_interface_edge(preset[3])
	_apply("interface_finish",v)
	if repeated: changed.emit("interface_finish")

func set_interface_opacity(v: float) -> void:
	_apply("interface_opacity",clampf(snappedf(v,0.01),0.70,1.0))

func set_interface_blur(v: float) -> void:
	_apply("interface_blur",clampf(snappedf(v,1.0),0.0,16.0))

func set_interface_gloss(v: float) -> void:
	_apply("interface_gloss",clampf(snappedf(v,0.01),0.0,0.30))

func set_interface_edge(v: float) -> void:
	_apply("interface_edge",clampf(snappedf(v,0.01),0.0,0.30))

func set_window_state(mode: String, monitor: int, size: Vector2i, maximized: bool = false, position: Vector2i = Vector2i(-100000, -100000)) -> void:
	if mode in WINDOW_MODES: _apply("window_mode", mode)
	set_window_monitor(monitor)
	set_window_size(size)
	_apply("window_x", position.x)
	_apply("window_y", position.y)
	set_window_maximized(maximized)

func window_size() -> Vector2i:
	return Vector2i(window_width, window_height)

func reset_scales() -> void:
	set_text_scale(1.0)
	set_ui_scale(1.0)
	set_render_scale(1.0)


func set_ui_volume(v: float) -> void:
	_apply("ui_volume", clampf(snappedf(v, 0.05), 0.0, 1.0))


func set_effects_volume(v: float) -> void:
	_apply("effects_volume", clampf(snappedf(v, 0.05), 0.0, 1.0))


func set_voice_volume(v: float) -> void:
	_apply("voice_volume", clampf(snappedf(v, 0.05), 0.0, 1.0))


func set_music_volume(v: float) -> void:
	_apply("music_volume", clampf(snappedf(v, 0.05), 0.0, 1.0))


func set_muted(v: bool) -> void:
	_apply("muted", v)


func _apply(key: String, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	if persist:
		_save()
	changed.emit(key)


func _load(path: String = PATH) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# The version is advisory: unknown keys and sections remain available to the
	# save path, while each known value is sanitized independently below.
	text_scale = clampf(float(cfg.get_value("display", "text_scale", 1.0)), TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	ui_scale = clampf(float(cfg.get_value("display", "ui_scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
	high_contrast = bool(cfg.get_value("accessibility", "high_contrast", false))
	reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", false))
	hints_enabled = bool(cfg.get_value("game", "hints_enabled", true))
	var saved_appearance: String = str(cfg.get_value("display", "appearance", "3d"))
	appearance = saved_appearance if saved_appearance in ["3d", "strategic"] else "3d"
	var saved_quality: String = str(cfg.get_value("display", "visual_quality", "auto"))
	visual_quality = saved_quality if saved_quality in ["auto", "low", "standard"] else "auto"
	var saved_mode: String = str(cfg.get_value("display", "view_mode", "command"))
	view_mode = saved_mode if saved_mode in ["command", "immersive"] else "command"
	var saved_window_mode: String = str(cfg.get_value("display", "window_mode", "windowed"))
	window_mode = saved_window_mode if saved_window_mode in WINDOW_MODES else "windowed"
	window_monitor = maxi(0, int(cfg.get_value("display", "window_monitor", 0)))
	window_width = clampi(int(cfg.get_value("display", "window_width", 1920)), WINDOW_WIDTH_MIN, WINDOW_WIDTH_MAX)
	window_height = clampi(int(cfg.get_value("display", "window_height", 1080)), WINDOW_HEIGHT_MIN, WINDOW_HEIGHT_MAX)
	window_x = int(cfg.get_value("display", "window_x", -100000))
	window_y = int(cfg.get_value("display", "window_y", -100000))
	window_maximized = bool(cfg.get_value("display", "window_maximized", false))
	render_scale = clampf(snappedf(float(cfg.get_value("display", "render_scale", 1.0)), 0.05), RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	var saved_vsync: String = str(cfg.get_value("display", "vsync_mode", "enabled"))
	vsync_mode = saved_vsync if saved_vsync in VSYNC_MODES else "enabled"
	var saved_cap: int = int(cfg.get_value("display", "frame_cap", 0))
	frame_cap = saved_cap if saved_cap in FRAME_CAPS else 0
	var saved_aa: String = str(cfg.get_value("display", "anti_aliasing", "2x"))
	anti_aliasing = saved_aa if saved_aa in ANTI_ALIASING_MODES else "2x"
	orbit_visible = bool(cfg.get_value("display", "orbit_visible", true))
	orbit_opacity = clampf(snappedf(float(cfg.get_value("display", "orbit_opacity", 0.72)), 0.05), 0.0, 1.0)
	var saved_finish: String = str(cfg.get_value("interface","finish","frosted"))
	interface_finish = saved_finish if saved_finish in ["matte","frosted","glossy"] else "frosted"
	interface_opacity = clampf(float(cfg.get_value("interface","opacity",0.82)),0.70,1.0)
	interface_blur = clampf(float(cfg.get_value("interface","blur",8.0)),0.0,16.0)
	interface_gloss = clampf(float(cfg.get_value("interface","gloss",0.10)),0.0,0.30)
	interface_edge = clampf(float(cfg.get_value("interface","edge",0.15)),0.0,0.30)
	ui_volume = clampf(float(cfg.get_value("audio", "ui_volume", 0.8)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value("audio", "effects_volume", 0.8)), 0.0, 1.0)
	voice_volume = clampf(float(cfg.get_value("audio", "voice_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.7)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", false))


func _save(path: String = PATH) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	# Load the existing file first instead of rebuilding it. This retains keys
	# from a newer build and unrelated application sections through a resave.
	cfg.load(path)
	cfg.set_value("display", "settings_version", DISPLAY_SETTINGS_VERSION)
	cfg.set_value("display", "text_scale", text_scale)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("accessibility", "high_contrast", high_contrast)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.set_value("game", "hints_enabled", hints_enabled)
	cfg.set_value("display", "appearance", appearance)
	cfg.set_value("display", "visual_quality", visual_quality)
	cfg.set_value("display", "view_mode", view_mode)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "window_monitor", window_monitor)
	cfg.set_value("display", "window_width", window_width)
	cfg.set_value("display", "window_height", window_height)
	cfg.set_value("display", "window_x", window_x)
	cfg.set_value("display", "window_y", window_y)
	cfg.set_value("display", "window_maximized", window_maximized)
	cfg.set_value("display", "render_scale", render_scale)
	cfg.set_value("display", "vsync_mode", vsync_mode)
	cfg.set_value("display", "frame_cap", frame_cap)
	cfg.set_value("display", "anti_aliasing", anti_aliasing)
	cfg.set_value("display", "orbit_visible", orbit_visible)
	cfg.set_value("display", "orbit_opacity", orbit_opacity)
	cfg.set_value("interface","version",1)
	cfg.set_value("interface","finish",interface_finish)
	cfg.set_value("interface","opacity",interface_opacity)
	cfg.set_value("interface","blur",interface_blur)
	cfg.set_value("interface","gloss",interface_gloss)
	cfg.set_value("interface","edge",interface_edge)
	cfg.set_value("audio", "ui_volume", ui_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	cfg.set_value("audio", "voice_volume", voice_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(path)
	if path == PATH and OS.has_feature("web"):
		JavaScriptBridge.eval("(() => { try { localStorage.setItem('"+WEB_VIEW_MODE_KEY+"', "+JSON.stringify(view_mode)+"); } catch (_) {} })()",true)
