extends RefCounted
## Display controls are application preferences. These tests cover the backend
## capability boundary and the recovery/retention behavior available headlessly.

func test_headless_does_not_advertise_native_window_controls(t: T) -> void:
	var caps: Dictionary = DisplaySettings.refresh_capabilities()
	if caps["headless"]:
		t.not_ok(caps["native_window"])
		t.empty(DisplaySettings.supported_window_modes())
		t.not_ok(DisplaySettings.supports("monitor_selection"))
		t.not_ok(DisplaySettings.preview_window({"mode":"fullscreen"})["ok"])
	else:
		t.ok(caps["native_window"], "a non-headless non-browser backend exposes native controls")
		t.ok(DisplaySettings.supported_window_modes().has("windowed"))
		var before: Dictionary = DisplaySettings.current_window_state()
		var preview: Dictionary = DisplaySettings.preview_window({"mode":before["mode"], "monitor":before["monitor"], "size":before["size"], "maximized":false}, 2.0)
		t.ok(preview["ok"], "native preview applies a validated window request")
		t.ok(DisplaySettings.preview_state()["active"])
		t.ok(DisplaySettings.revert_preview(), "native preview can recover the previous rectangle")


func test_native_preview_keep_timeout_and_invalid_monitor_recovery(t: T) -> void:
	if not DisplaySettings.supports("native_window"):
		t.ok(DisplaySettings.capabilities().get("headless", false) or DisplaySettings.capabilities().get("web", false), "native preview is unavailable only on gated backends")
		return
	var before: Dictionary = DisplaySettings.current_window_state()
	var old_persist: bool = Settings.persist
	Settings.persist = false
	var request: Dictionary = {"mode":"windowed", "monitor":999, "size":Vector2i(1000, 700), "maximized":false}
	var preview: Dictionary = DisplaySettings.preview_window(request, 0.05)
	t.ok(preview["ok"])
	t.eq(preview["state"]["target"]["monitor"], 0, "an invalid monitor is clamped to the available display")
	t.ok(DisplaySettings.keep_preview(), "a native preview can be kept")
	t.eq(Settings.window_size(), Vector2i(1000, 700))
	# Revert through a second preview, then verify automatic expiry restores the
	# exact pre-preview mode and rectangle.
	var before_expiry: Dictionary = DisplaySettings.current_window_state()
	DisplaySettings.preview_window({"mode":before["mode"], "monitor":before["monitor"], "size":before["size"], "position":before["position"], "maximized":before["maximized"]}, 0.05)
	OS.delay_msec(80)
	for i: int in 3: await Engine.get_main_loop().process_frame
	t.not_ok(DisplaySettings.preview_state()["active"], "an unanswered preview expires")
	var after: Dictionary = DisplaySettings.current_window_state()
	t.eq(after["mode"], before_expiry["mode"])
	t.eq(after["size"], before_expiry["size"])
	t.eq(after["position"], before_expiry["position"])
	Settings.persist = old_persist
	Settings.set_window_state(str(before["mode"]), int(before["monitor"]), before["size"], bool(before["maximized"]), before["position"])


func test_display_settings_sanitize_fine_steps_and_retain_unknown_config(t: T) -> void:
	var path: String = "user://m12_display_settings_%d.cfg" % Time.get_ticks_usec()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "settings_version", 99)
	cfg.set_value("display", "text_scale", 0.1)
	cfg.set_value("display", "render_scale", 4.75)
	cfg.set_value("display", "window_mode", "future_mode")
	cfg.set_value("display", "window_width", 40)
	cfg.set_value("display", "window_height", 99999)
	cfg.set_value("future_section", "future_fraction", 0.125)
	cfg.set_value("display", "future_display_field", "retain")
	cfg.save(path)
	Settings._load(path)
	t.eq(Settings.text_scale, Settings.TEXT_SCALE_MIN)
	t.eq(Settings.render_scale, Settings.RENDER_SCALE_MAX)
	t.eq(Settings.window_mode, "windowed")
	t.eq(Settings.window_width, Settings.WINDOW_WIDTH_MIN)
	t.eq(Settings.window_height, Settings.WINDOW_HEIGHT_MAX)
	Settings._save(path)
	var retained: ConfigFile = ConfigFile.new(); retained.load(path)
	t.eq(retained.get_value("future_section", "future_fraction", 0.0), 0.125)
	t.eq(retained.get_value("display", "future_display_field", ""), "retain")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings._load()


func test_runtime_graphics_settings_are_sanitized_and_preserve_independent_scales(t: T) -> void:
	var old_render: float = Settings.render_scale
	var old_cap: int = Settings.frame_cap
	var old_aa: String = Settings.anti_aliasing
	Settings.persist = false
	Settings.set_render_scale(0.876)
	t.eq(Settings.render_scale, 0.9)
	Settings.set_frame_cap(60)
	t.eq(Settings.frame_cap, 60)
	Settings.set_anti_aliasing("4x")
	t.eq(Settings.anti_aliasing, "4x")
	Settings.set_window_size(Vector2i(1, 99999))
	t.eq(Settings.window_size(), Vector2i(Settings.WINDOW_WIDTH_MIN, Settings.WINDOW_HEIGHT_MAX))
	Settings.set_render_scale(old_render)
	Settings.set_frame_cap(old_cap)
	Settings.set_anti_aliasing(old_aa)


func test_size_presets_are_independent_of_render_and_ui_scale(t: T) -> void:
	var presets: Dictionary = DisplaySettings.window_size_presets()
	t.eq(presets["small"], Vector2i(1280, 720))
	t.eq(presets["standard"], Vector2i(1600, 900))
	t.eq(presets["large"], Vector2i(1920, 1080))
	var old_scale: float = Settings.ui_scale
	Settings.persist = false
	Settings.set_ui_scale(1.5)
	t.eq(presets["small"], Vector2i(1280, 720), "presets describe window pixels, not interface scale")
	Settings.set_ui_scale(old_scale)


func test_production_world_host_applies_supported_graphics_to_world(t: T) -> void:
	if DisplaySettings.capabilities().get("headless", false):
		t.ok(not DisplaySettings.supports("render_scale"), "headless cannot claim a production render-scale backend")
		return
	if not DisplaySettings.supports("render_scale"):
		t.eq(DisplaySettings.capabilities().get("render_scale_reason", ""), "renderer_scaling_3d_unavailable", "unsupported 3D scaling is reported instead of faking a control")
	var old_render: float = Settings.render_scale
	var old_aa: String = Settings.anti_aliasing
	Settings.persist = false
	Settings.set_hints_enabled(false); Settings.set_reduce_motion(true); Settings.set_appearance("3d")
	Game.new_game("s1_first_light", 11); GameScreen._opened_seed = 11
	var screen: GameScreen = GameScreen.new()
	Engine.get_main_loop().root.add_child(screen)
	screen.show_view(GameScreen.SYSTEM)
	for i: int in 8: await Engine.get_main_loop().process_frame
	var host: WorldViewportHost = screen.world_controller.host
	var initial: Dictionary = host.graphics_metrics()
	t.ok(initial.get("mounted", false), "production world host exposes a mounted SubViewport")
	t.ok(Vector2i(initial.get("viewport_size", Vector2i.ZERO)).x > 0, "production viewport has a real pixel size")
	Settings.set_render_scale(0.65); Settings.set_anti_aliasing("4x")
	for i2: int in 3: await Engine.get_main_loop().process_frame
	var applied: Dictionary = host.graphics_metrics()
	t.near(float(applied.get("render_scale", 0.0)), 0.65 if DisplaySettings.supports("render_scale") else 1.0, 0.001)
	t.eq(applied.get("msaa"), Viewport.MSAA_4X)
	t.near(float(applied.get("effective_pixel_ratio", 0.0)), float(applied.get("render_scale", 1.0)) / float(applied.get("quality_divisor", 1)), 0.001)
	host.deactivate()
	screen.queue_free()
	for i3: int in 5: await Engine.get_main_loop().process_frame
	Worlds.restart()
	Settings.set_render_scale(old_render); Settings.set_anti_aliasing(old_aa); Settings.set_appearance("strategic")
