class_name SettingsScreen
extends FlowScreen
## Settings (§5.13, §7 screen 14): sound (each bus and mute), display (text size, interface scale,
## high contrast, reduced motion) and play (advisor hints). Changes apply at once and are saved.
## Sliders that rebuild the layout (text size, scale) apply when released, so a drag is not
## interrupted by the screen being rebuilt under it.

var _dragging: bool = false
var _display_keep_button: SfButton
var _display_revert_button: SfButton
var _display_preview_note: Label


static func make(p_back: String = AppRoot.TITLE) -> SettingsScreen:
	var s: SettingsScreen = SettingsScreen.new()
	s.name = "SettingsScreen"
	s.back_route = p_back
	return s


func _ready() -> void:
	super._ready()
	DisplaySettings.preview_changed.connect(_on_preview_changed)
	_on_preview_changed(DisplaySettings.preview_state())


func _exit_tree() -> void:
	if DisplaySettings.preview_changed.is_connected(_on_preview_changed): DisplaySettings.preview_changed.disconnect(_on_preview_changed)
	if DisplaySettings.preview_state().get("active", false): DisplaySettings.revert_preview()


func build_screen() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	col.add_child(header(Strings.fmt("ui.settings.title")))
	var left: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	left.add_child(_sound())
	left.add_child(_play())
	var right: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	right.add_child(_display())
	right.add_child(_about())
	col.add_child(FlowScreen.scroll_of(GameUI.split(left, right)))


func _sound() -> Control:
	var card: Card = Card.make(Strings.fmt("ui.settings.sound"), "", "ui_sound", "accent.teal")
	card.name = "SoundCard"
	card.add_body(_slider("ui.settings.ui_volume", Settings.ui_volume, 0.0, 1.0, 0.05, Settings.set_ui_volume, true))
	card.add_body(_slider("ui.settings.effects_volume", Settings.effects_volume, 0.0, 1.0, 0.05, Settings.set_effects_volume, true))
	card.add_body(_slider("ui.settings.voice_volume", Settings.voice_volume, 0.0, 1.0, 0.05, Settings.set_voice_volume, true))
	card.add_body(_slider("ui.settings.music_volume", Settings.music_volume, 0.0, 1.0, 0.05, Settings.set_music_volume, true))
	card.add_body(_toggle("ui.settings.mute", Settings.muted, Settings.set_muted))
	return card


func _display() -> Control:
	var card: Card = Card.make(Strings.fmt("ui.settings.display"), "", "ui_display", "accent.teal")
	card.name = "DisplayCard"
	card.add_body(_slider("ui.settings.text_size", Settings.text_scale, Settings.TEXT_SCALE_MIN, Settings.TEXT_SCALE_MAX, 0.05, Settings.set_text_scale, false))
	card.add_body(_slider("ui.settings.ui_scale", Settings.ui_scale, Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX, 0.05, Settings.set_ui_scale, false))
	if DisplaySettings.supports("render_scale"):
		card.add_body(_slider("ui.settings.display_render_scale", Settings.render_scale, Settings.RENDER_SCALE_MIN, Settings.RENDER_SCALE_MAX, 0.05, Settings.set_render_scale, false))
		card.add_text(Strings.fmt("ui.settings.display_render_scale_note"), &"CaptionLabel")
	else:
		card.add_text(Strings.fmt("ui.settings.display_render_scale_unavailable"), &"CaptionLabel")
	card.add_body(_button_row("ui.settings.display_reset", Settings.reset_scales, "ui_reroll"))
	card.add_body(_toggle("ui.settings.high_contrast", Settings.high_contrast, Settings.set_high_contrast))
	card.add_body(_toggle("ui.settings.reduce_motion", Settings.reduce_motion, Settings.set_reduce_motion))
	card.add_body(choice("ui.world.appearance",["3d","strategic"],["ui.world.spatial","ui.world.strategic"],Settings.appearance,Settings.set_appearance))
	card.add_body(choice("ui.world.view_mode",["command","immersive"],["ui.world.command","ui.world.immersive"],Settings.view_mode,Settings.set_view_mode))
	card.add_text(Strings.fmt("ui.world.immersive_help"), &"CaptionLabel")
	card.add_body(choice("ui.world.quality",["auto","low","standard"],["ui.world.auto","ui.world.low","ui.world.standard"],Settings.visual_quality,Settings.set_visual_quality))
	WorldViewTools.add_interface_controls(card)
	if DisplaySettings.supports("vsync"):
		card.add_body(choice("ui.settings.display_vsync", Settings.VSYNC_MODES, ["ui.settings.vsync_disabled", "ui.settings.vsync_enabled", "ui.settings.vsync_adaptive", "ui.settings.vsync_mailbox"], Settings.vsync_mode, Settings.set_vsync_mode))
	if DisplaySettings.supports("frame_cap"):
		card.add_body(choice("ui.settings.display_frame_cap", ["0", "30", "60", "90", "120", "144", "240"], ["ui.settings.frame_unlimited", "ui.settings.frame_30", "ui.settings.frame_60", "ui.settings.frame_90", "ui.settings.frame_120", "ui.settings.frame_144", "ui.settings.frame_240"], str(Settings.frame_cap), _set_frame_cap))
	if DisplaySettings.supports("anti_aliasing"):
		card.add_body(choice("ui.settings.display_anti_aliasing", Settings.ANTI_ALIASING_MODES, ["ui.settings.aa_disabled", "ui.settings.aa_2x", "ui.settings.aa_4x", "ui.settings.aa_8x"], Settings.anti_aliasing, Settings.set_anti_aliasing))
	if DisplaySettings.supports("native_window"):
		card.add_body(choice("ui.settings.display_mode", DisplaySettings.supported_window_modes(), ["ui.settings.windowed", "ui.settings.borderless", "ui.settings.fullscreen", "ui.settings.exclusive_fullscreen"], Settings.window_mode, _preview_mode))
		card.add_body(_window_size_choice())
		card.add_body(_window_manual_size())
		if DisplaySettings.monitor_count() > 1:
			card.add_body(_monitor_choice())
		card.add_body(_window_actions())
	elif DisplaySettings.supports("browser_fullscreen"):
		card.add_body(_button_row("ui.settings.display_browser_fullscreen", DisplaySettings.request_browser_fullscreen, "ui_display"))
	else:
		card.add_text(Strings.fmt("ui.settings.display_native_unavailable"), &"CaptionLabel")
	return card


func _set_frame_cap(value: String) -> void:
	Settings.set_frame_cap(int(value))


func _window_target() -> Dictionary:
	var preview: Dictionary = DisplaySettings.preview_state()
	var target: Variant = preview.get("target", {}) if preview.get("active", false) else {}
	if not target is Dictionary or target.is_empty():
		target = {"mode":Settings.window_mode, "monitor":Settings.window_monitor, "size":Settings.window_size(), "maximized":Settings.window_maximized}
	return (target as Dictionary).duplicate(true)


func _preview_mode(mode: String) -> void:
	var target: Dictionary = _window_target(); target["mode"] = mode
	DisplaySettings.preview_window(target)


func _preview_size_key(key: String) -> void:
	var presets: Dictionary = DisplaySettings.window_size_presets()
	if not presets.has(key): return
	var target: Dictionary = _window_target(); target["size"] = presets[key]
	DisplaySettings.preview_window(target)


func _window_size_choice() -> Control:
	var presets: Dictionary = DisplaySettings.window_size_presets()
	var current: String = "custom"
	for key: String in presets:
		if presets[key] == Settings.window_size(): current = key
	var values: Array[String] = ["small", "standard", "large"]
	var labels: Array[String] = ["ui.settings.size_small", "ui.settings.size_standard", "ui.settings.size_large"]
	return choice("ui.settings.display_size", values, labels, current, _preview_size_key)


func _monitor_choice() -> Control:
	var values: Array[String] = []
	var labels: Array[String] = []
	for i: int in DisplaySettings.monitor_count():
		values.append(str(i)); labels.append(Strings.fmt("ui.settings.monitor_label", {"number":i + 1}))
	return choice("ui.settings.display_monitor", values, labels, str(Settings.window_monitor), _preview_monitor)


func _preview_monitor(value: String) -> void:
	var target: Dictionary = _window_target(); target["monitor"] = int(value)
	DisplaySettings.preview_window(target)


func _window_manual_size() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	var label: Label = FlowScreen.label(Strings.fmt("ui.settings.display_custom_size"), &"SecondaryLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var width: SpinBox = SpinBox.new()
	width.name = "WindowWidth"
	width.min_value = Settings.WINDOW_WIDTH_MIN; width.max_value = Settings.WINDOW_WIDTH_MAX; width.step = 1
	width.value = Settings.window_width; width.custom_minimum_size.x = 110
	width.value_changed.connect(func(value: float) -> void: _preview_dimension(true, roundi(value)))
	row.add_child(GameUI.exempt(width, "window width in pixels"))
	var height: SpinBox = SpinBox.new()
	height.name = "WindowHeight"
	height.min_value = Settings.WINDOW_HEIGHT_MIN; height.max_value = Settings.WINDOW_HEIGHT_MAX; height.step = 1
	height.value = Settings.window_height; height.custom_minimum_size.x = 110
	height.value_changed.connect(func(value: float) -> void: _preview_dimension(false, roundi(value)))
	row.add_child(GameUI.exempt(height, "window height in pixels"))
	return GameUI.exempt(row, "custom native window dimensions")


func _preview_dimension(width: bool, value: int) -> void:
	var target: Dictionary = _window_target()
	var size: Vector2i = target.get("size", Settings.window_size())
	if width: size.x = value
	else: size.y = value
	target["size"] = size
	DisplaySettings.preview_window(target)


func _window_actions() -> Control:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	var apply: SfButton = SfButton.make("ui.settings.display_apply", "ui_check", SfButton.SECONDARY)
	apply.name = "ApplyDisplay"
	apply.pressed.connect(func() -> void: DisplaySettings.preview_window(_window_target()))
	var maximize: SfButton = SfButton.make("ui.settings.display_maximize", "ui_plus", SfButton.SECONDARY)
	maximize.name = "MaximizeDisplay"
	maximize.pressed.connect(func() -> void:
		var target: Dictionary = _window_target(); target["mode"] = "windowed"; target["maximized"] = true; DisplaySettings.preview_window(target))
	var restore: SfButton = SfButton.make("ui.settings.display_restore", "ui_undo", SfButton.SECONDARY)
	restore.name = "RestoreDisplay"
	restore.pressed.connect(func() -> void:
		var target: Dictionary = _window_target(); target["mode"] = "windowed"; target["maximized"] = false; DisplaySettings.preview_window(target))
	var keep: SfButton = SfButton.make("ui.settings.display_keep", "ui_check", SfButton.PRIMARY)
	keep.name = "KeepDisplay"
	keep.pressed.connect(DisplaySettings.keep_preview)
	var revert: SfButton = SfButton.make("ui.settings.display_revert", "ui_close", SfButton.SECONDARY)
	revert.name = "RevertDisplay"
	revert.pressed.connect(DisplaySettings.revert_preview)
	_display_keep_button = keep; _display_revert_button = revert
	row.add_child(GameUI.exempt(apply, "apply a reversible display preview"))
	row.add_child(GameUI.exempt(maximize, "preview a maximized window"))
	row.add_child(GameUI.exempt(restore, "preview a restored window"))
	row.add_child(GameUI.exempt(keep, "confirm a reversible display preview"))
	row.add_child(GameUI.exempt(revert, "restore the previous display rectangle"))
	_display_preview_note = FlowScreen.label("", &"CaptionLabel")
	row.add_child(GameUI.exempt(_display_preview_note, "display preview countdown"))
	_on_preview_changed(DisplaySettings.preview_state())
	return row


func _on_preview_changed(state: Dictionary) -> void:
	var active: bool = bool(state.get("active", false))
	if is_instance_valid(_display_keep_button): _display_keep_button.disabled = not active
	if is_instance_valid(_display_revert_button): _display_revert_button.disabled = not active
	if is_instance_valid(_display_preview_note):
		_display_preview_note.text = Strings.fmt("ui.settings.display_preview", {"seconds":int(state.get("remaining_seconds", DisplaySettings.PREVIEW_SECONDS))}) if active else ""


func _button_row(title_key: String, apply: Callable, icon: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var button: SfButton = SfButton.make(title_key, icon, SfButton.SECONDARY)
	button.name = title_key.get_slice(".", 2).capitalize()
	button.pressed.connect(apply)
	row.add_child(button)
	return GameUI.exempt(row, "apply a display preference")

static func choice(key: String, values: Array, labels: Array, current: String, apply: Callable) -> Control:
	var row: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
	row.add_child(GameUI.caption(Strings.fmt(key)))
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	buttons.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in values.size():
		var button: SfButton = SfButton.make(labels[i], "", SfButton.TAB)
		button.name = key.get_slice(".",2).capitalize() + "_" + str(values[i])
		button.button_group = group; button.button_pressed = current == values[i]
		button.pressed.connect(apply.bind(str(values[i])))
		buttons.add_child(GameUI.exempt(button,"3D names an appearance setting"))
	row.add_child(buttons)
	return row


func _play() -> Control:
	var card: Card = Card.make(Strings.fmt("ui.settings.play"), "", "ui_advisor", "accent.teal")
	card.name = "PlayCard"
	card.add_body(_toggle("ui.settings.hints", Settings.hints_enabled, Settings.set_hints_enabled))
	card.add_text(Strings.fmt("ui.settings.hints_note"), &"CaptionLabel")
	return card


func _about() -> Control:
	var card: Card = Card.make(Strings.fmt("ui.settings.about"), "", "emblem_hearth", "hearth.gold")
	card.name = "AboutCard"
	var credits: SfButton = SfButton.make("ui.settings.credits", "ui_star", SfButton.SECONDARY)
	credits.name = "Credits"
	credits.pressed.connect(go.bind(AppRoot.CREDITS, {"back": AppRoot.SETTINGS}))
	card.add_body(credits)
	return card


## A labelled slider. `live` applies every change; otherwise the value applies when the
## slider is released (or changed from the keyboard).
func _slider(title_key: String, value: float, lo: float, hi: float, step: float, apply: Callable, live: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	var t: Label = FlowScreen.label(Strings.fmt(title_key), &"SecondaryLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.custom_minimum_size.x = 120.0
	row.add_child(t)
	var sl: HSlider = HSlider.new()
	sl.name = "Slider_" + title_key.get_slice(".", 2)
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(200.0 * Settings.text_scale, Layout.target_size())
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var v: Label = Label.new()
	v.theme_type_variation = &"MonoLabel"
	v.text = "%d%%" % roundi(value * 100.0)
	v.custom_minimum_size.x = 56.0
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	sl.value_changed.connect(func(x: float) -> void:
		v.text = "%d%%" % roundi(x * 100.0)
		if live or not _dragging:
			apply.call(x))
	if not live:
		sl.drag_started.connect(func() -> void: _dragging = true)
		sl.drag_ended.connect(func(_changed: bool) -> void:
			_dragging = false
			apply.call(sl.value))
	return GameUI.exempt(row, "a setting's value as a percentage")


func _toggle(title_key: String, on: bool, apply: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	var t: Label = FlowScreen.label(Strings.fmt(title_key), &"SecondaryLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var b: SfButton = SfButton.make("ui.settings.on" if on else "ui.settings.off", "ui_check" if on else "ui_close", SfButton.TAB)
	b.name = "Toggle_" + title_key.get_slice(".", 2)
	b.button_pressed = on
	b.toggled.connect(func(pressed: bool) -> void:
		b.text = Strings.fmt("ui.settings.on" if pressed else "ui.settings.off")
		b.set_icon_id("ui_check" if pressed else "ui_close")
		apply.call(pressed))
	row.add_child(b)
	return row
