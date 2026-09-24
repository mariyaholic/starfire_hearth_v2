extends Node
## Responsive layout helper (§7 layout base).
##
## Scale: on a pointer device the UI is designed at 1080p and grows with the window
## (never shrinks below 1.0, so text stays readable in small windows); on a touch device one
## logical pixel is one density-independent pixel (dp), so 48-unit targets are 48 dp.
## The user's UI scale multiplies either. Layout class: "compact" when the logical window is
## narrower than 1280 or shorter than 700; screens switch to their phone layouts then.

signal changed
## Emitted after the theme was rebuilt (text scale, layout class, touch mode or contrast changed).
signal theme_rebuilt

enum Profile { AUTO, PC, PHONE }

const COMPACT_MAX_WIDTH: float = 1280.0
const COMPACT_MAX_HEIGHT: float = 700.0
## The reference phone of §7: 2400x1080, 6 inches, about 440 dpi (Android density 2.75).
const PHONE_DPI: float = 440.0
## Simulated display cut-outs for the forced phone profile (dp): camera on the left in landscape,
## gesture bar at the bottom.
const PHONE_SAFE_MARGINS: Vector4 = Vector4(32, 0, 0, 12)

var profile: Profile = Profile.AUTO
## Physical pixels per logical pixel.
var scale: float = 1.0
var logical_size: Vector2 = Vector2(1920, 1080)
var compact: bool = false
var touch_ui: bool = false
## Safe-area margins in logical pixels: left, top, right, bottom.
var safe_margins: Vector4 = Vector4.ZERO
## The theme applied to the root window.
var theme: Theme = null
var _theme_key: String = ""
## The layout class last written to the browser console.
var _logged: String = ""


func _ready() -> void:
	get_window().size_changed.connect(refresh)
	Settings.changed.connect(_on_setting)
	refresh()


func set_profile(p: Profile) -> void:
	profile = p
	refresh()


## Minimum size for anything you can press: 48 dp on touch, 32 px with a pointer.
func target_size() -> float:
	return float(Tokens.TOUCH_TARGET_DP) if touch_ui else float(Tokens.POINTER_TARGET_PX)


## The layout class, for logs: "compact, touch", "wide, pointer" and so on.
func describe() -> String:
	return "%s, %s" % ["compact" if compact else "wide", "touch" if touch_ui else "pointer"]


func refresh() -> void:
	var win: Window = get_window()
	var size: Vector2 = Vector2(win.size)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var device_touch: bool = _is_touch_device()
	var mobile: bool = device_touch
	match profile:
		Profile.PC:
			mobile = false
		Profile.PHONE:
			mobile = true
	touch_ui = mobile
	var desired: float
	if mobile:
		desired = _touch_scale(device_touch)
	else:
		desired = maxf(1.0, size.y / 1080.0)
	desired *= Settings.ui_scale
	var base: float = minf(size.x / 1920.0, size.y / 1080.0)
	win.content_scale_factor = desired / base
	scale = desired
	logical_size = size / desired
	compact = logical_size.x < COMPACT_MAX_WIDTH or logical_size.y < COMPACT_MAX_HEIGHT
	safe_margins = _safe_margins(win, desired, device_touch)
	# The browser console is where web playtest reports come from, so say which layout was chosen.
	if OS.has_feature("web") and describe() != _logged:
		_logged = describe()
		print("Starfire Hearth layout: %s, UI scale %.2f, %dx%d logical" % [_logged, scale, roundi(logical_size.x), roundi(logical_size.y)])
	_apply_theme()
	changed.emit()


func _apply_theme() -> void:
	var key: String = "%s|%s|%s|%s" % [Settings.text_scale, compact, touch_ui, Settings.high_contrast]
	if key == _theme_key:
		return
	_theme_key = key
	theme = ThemeBuilder.build(Settings.text_scale, compact, touch_ui, Settings.high_contrast)
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(Tokens.color("bg.deep"))
	theme_rebuilt.emit()


## Phones and tablets: native mobile builds, and browsers that report a phone or tablet system or
## whose main pointer is a finger (iPadOS Safari reports itself as macOS).
func _is_touch_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		# JavaScript booleans arrive as integers.
		var coarse: Variant = JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true)
		return typeof(coarse) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and bool(coarse)
	return false


func _touch_scale(device_touch: bool) -> float:
	if not device_touch:
		# The phone profile forced on a PC simulates the reference phone.
		return PHONE_DPI / 160.0
	if OS.has_feature("web"):
		# A CSS pixel on a phone or tablet browser is one dp.
		return maxf(1.0, DisplayServer.screen_get_scale())
	return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)


func _safe_margins(win: Window, desired: float, device_touch: bool) -> Vector4:
	if profile == Profile.PHONE and not device_touch:
		return PHONE_SAFE_MARGINS
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win_rect: Rect2i = Rect2i(win.position, win.size)
	var left: float = maxf(0.0, safe.position.x - win_rect.position.x)
	var top: float = maxf(0.0, safe.position.y - win_rect.position.y)
	var right: float = maxf(0.0, win_rect.end.x - safe.end.x)
	var bottom: float = maxf(0.0, win_rect.end.y - safe.end.y)
	return Vector4(left, top, right, bottom) / desired


func _on_setting(key: String) -> void:
	if key == "ui_scale":
		refresh()
	elif key == "text_scale" or key == "high_contrast":
		_apply_theme()
		changed.emit()
