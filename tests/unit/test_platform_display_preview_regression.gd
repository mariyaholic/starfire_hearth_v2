extends RefCounted


func test_platform_preview_recovery_and_malformed_request(t: T) -> void:
	if not DisplaySettings.supports("native_window"):
		t.ok(true, "native window lifecycle requires a window backend")
		return
	var before: Dictionary = DisplaySettings.current_window_state()
	var old_persist: bool = Settings.persist
	Settings.persist = false
	var invalid: Dictionary = DisplaySettings.preview_window({"mode": "windowed", "monitor": {}, "size": "bad", "position": "bad"})
	t.ok(invalid["ok"], "malformed optional fields fall back safely")
	DisplaySettings.revert_preview()
	var first: Dictionary = {"mode": "windowed", "monitor": 0, "size": Vector2i(1000, 700), "maximized": false}
	var second: Dictionary = {"mode": "windowed", "monitor": 0, "size": Vector2i(1200, 800), "maximized": false}
	t.ok(DisplaySettings.preview_window(first)["ok"])
	t.ok(DisplaySettings.preview_window(second)["ok"])
	t.ok(DisplaySettings.revert_preview())
	var restored: Dictionary = DisplaySettings.current_window_state()
	t.eq(restored["mode"], before["mode"], "multiple previews restore the original mode")
	t.eq(restored["size"], before["size"], "multiple previews restore the original size")
	t.eq(restored["position"], before["position"], "multiple previews restore the original position")
	DisplaySettings.preview_window(first)
	DisplaySettings._on_focus_exited()
	t.not_ok(DisplaySettings.preview_state()["active"], "focus loss reverts preview")
	DisplaySettings.preview_window(first, 0.02)
	OS.delay_msec(40)
	DisplaySettings._process(0.0)
	t.not_ok(DisplaySettings.preview_state()["active"], "deadline reverts preview")
	DisplaySettings.preview_window(first)
	DisplaySettings._exit_tree()
	t.not_ok(DisplaySettings.preview_state()["active"], "service exit reverts preview")
	DisplaySettings.preview_window(first)
	t.ok(DisplaySettings.keep_preview())
	t.eq(Settings.window_size(), Vector2i(1000, 700), "keep persists the target settings")
	t.not_ok(DisplaySettings.preview_state()["active"])
	Settings.set_window_state(str(before["mode"]), int(before["monitor"]), before["size"], bool(before["maximized"]), before["position"])
	Settings.persist = old_persist


func test_platform_fullscreen_to_borderless_retains_windowed_rectangle(t: T) -> void:
	if not DisplaySettings.supports("native_window"):
		t.ok(true, "native window lifecycle requires a window backend")
		return
	var old_persist: bool = Settings.persist
	Settings.persist = false
	var before: Dictionary = DisplaySettings.current_window_state()
	var initial: Dictionary = {"mode": "windowed", "monitor": 0, "size": Vector2i(1000, 700), "position": Vector2i(80, 80), "maximized": false}
	DisplaySettings.preview_window(initial)
	DisplaySettings.keep_preview()
	DisplaySettings.preview_window({"mode": "borderless", "monitor": 0})
	DisplaySettings.keep_preview()
	for i: int in 3: await Engine.get_main_loop().process_frame
	DisplaySettings.preview_window({"mode": "fullscreen", "monitor": 0})
	DisplaySettings.keep_preview()
	t.eq(Settings.window_size(), Vector2i(1000, 700), "changing between full-screen modes retains the windowed size")
	t.eq(Vector2i(Settings.window_x, Settings.window_y), Vector2i(80, 80), "changing between full-screen modes retains the windowed position")
	Settings.set_window_state(str(before["mode"]), int(before["monitor"]), before["size"], bool(before["maximized"]), before["position"])
	Settings.persist = old_persist
