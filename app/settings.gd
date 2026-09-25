extends Node
## Player settings (§6.9, §7 screen 13), saved to user://settings.cfg.
## Screens read these and listen to `changed`; nothing here touches simulation state.

signal changed(key: String)

const PATH: String = "user://settings.cfg"
const TEXT_SCALE_MIN: float = 1.0
const TEXT_SCALE_MAX: float = 2.0
const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.5

## Text size multiplier, 100% to 200%. Layouts reflow; they never overlap.
var text_scale: float = 1.0
## User multiplier on top of the automatic UI scale.
var ui_scale: float = 1.0
var reduce_motion: bool = false
var high_contrast: bool = false
var hints_enabled: bool = true
## Volumes of the UI, Effects and Music buses, 0 to 1 (§8.6).
var ui_volume: float = 0.8
var effects_volume: float = 0.8
var music_volume: float = 0.7
var muted: bool = false
## When false (tests, the screenshot tour) nothing is written to disk.
var persist: bool = true


func _init() -> void:
	_load()


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


func set_ui_volume(v: float) -> void:
	_apply("ui_volume", clampf(snappedf(v, 0.05), 0.0, 1.0))


func set_effects_volume(v: float) -> void:
	_apply("effects_volume", clampf(snappedf(v, 0.05), 0.0, 1.0))


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


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	text_scale = clampf(float(cfg.get_value("display", "text_scale", 1.0)), TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	ui_scale = clampf(float(cfg.get_value("display", "ui_scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
	high_contrast = bool(cfg.get_value("accessibility", "high_contrast", false))
	reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", false))
	hints_enabled = bool(cfg.get_value("game", "hints_enabled", true))
	ui_volume = clampf(float(cfg.get_value("audio", "ui_volume", 0.8)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value("audio", "effects_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.7)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", false))


func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "text_scale", text_scale)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("accessibility", "high_contrast", high_contrast)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.set_value("game", "hints_enabled", hints_enabled)
	cfg.set_value("audio", "ui_volume", ui_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(PATH)
