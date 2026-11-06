extends RefCounted

const SettingsScript = preload("res://app/settings.gd")


func test_platform_malformed_config_and_nonfinite_setters(t: T) -> void:
	var path: String = "/tmp/starfire_platform_settings_%d.cfg" % Time.get_ticks_usec()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "text_scale", [1, 2])
	cfg.set_value("display", "window_width", {"bad": 1})
	cfg.set_value("display", "window_maximized", "false")
	cfg.set_value("audio", "muted", "false")
	cfg.set_value("audio", "voice_volume", "invalid")
	cfg.set_value("interface", "blur", [8])
	cfg.save(path)
	var settings: Node = SettingsScript.new()
	settings.persist = false
	settings._load(path)
	t.eq(settings.text_scale, 1.0, "invalid scale falls back to its default")
	t.eq(settings.window_width, 1920, "invalid width falls back to its default")
	t.eq(settings.window_maximized, false, "invalid boolean cannot become true")
	t.eq(settings.muted, false, "invalid boolean cannot mute audio")
	t.eq(settings.voice_volume, 0.8, "invalid volume falls back to its default")
	t.eq(settings.interface_blur, 8.0, "invalid blur falls back to its default")
	settings.set_ui_scale(NAN)
	t.ok(is_finite(settings.ui_scale), "nonfinite runtime scale cannot enter layout")
	settings.set_voice_volume(NAN)
	t.ok(is_finite(settings.voice_volume), "nonfinite volume cannot enter the audio bus")
	settings.free()
	DirAccess.remove_absolute(path)
