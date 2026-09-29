class_name SettingsScreen
extends FlowScreen
## Settings (§5.13, §7 screen 14): sound (each bus and mute), display (text size, interface scale,
## high contrast, reduced motion) and play (advisor hints). Changes apply at once and are saved.
## Sliders that rebuild the layout (text size, scale) apply when released, so a drag is not
## interrupted by the screen being rebuilt under it.

var _dragging: bool = false


static func make(p_back: String = AppRoot.TITLE) -> SettingsScreen:
	var s: SettingsScreen = SettingsScreen.new()
	s.name = "SettingsScreen"
	s.back_route = p_back
	return s


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
	card.add_body(_slider("ui.settings.music_volume", Settings.music_volume, 0.0, 1.0, 0.05, Settings.set_music_volume, true))
	card.add_body(_toggle("ui.settings.mute", Settings.muted, Settings.set_muted))
	return card


func _display() -> Control:
	var card: Card = Card.make(Strings.fmt("ui.settings.display"), "", "ui_display", "accent.teal")
	card.name = "DisplayCard"
	card.add_body(_slider("ui.settings.text_size", Settings.text_scale, Settings.TEXT_SCALE_MIN, Settings.TEXT_SCALE_MAX, 0.25, Settings.set_text_scale, false))
	card.add_body(_slider("ui.settings.ui_scale", Settings.ui_scale, Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX, 0.25, Settings.set_ui_scale, false))
	card.add_body(_toggle("ui.settings.high_contrast", Settings.high_contrast, Settings.set_high_contrast))
	card.add_body(_toggle("ui.settings.reduce_motion", Settings.reduce_motion, Settings.set_reduce_motion))
	return card


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
