class_name OverlayLayer
extends Control
## Base for full-window overlays (Modal, Drawer, BottomSheet): a scrim, a panel, open and dismiss
## animations that respect Reduce Motion, and dismissal by Esc/back or by tapping the scrim.

signal dismissed

## False for blocking overlays (a critical alert must be answered, not waved away).
var dismissable: bool = true
var panel: PanelContainer
var _scrim: ColorRect
var _closing: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim = ColorRect.new()
	_scrim.color = Color(Tokens.color("bg.deep"), 0.72)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)
	add_to_group("overlay_layer")


## Adds this overlay to the Overlay host and animates it in.
func open() -> OverlayLayer:
	Overlay.push(self)
	_animate_in()
	return self


func dismiss() -> void:
	if not dismissable or _closing:
		return
	close()


## Closes even a blocking overlay (after its choice was made).
func close() -> void:
	if _closing:
		return
	_closing = true
	dismissed.emit()
	if Settings.reduce_motion or not is_inside_tree():
		queue_free()
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, Tokens.TWEEN_FAST)
	tw.tween_callback(queue_free)


func _animate_in() -> void:
	if Settings.reduce_motion:
		return
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, Tokens.TWEEN_NORMAL).set_ease(Tween.EASE_OUT)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dismiss()


## Header row with a title and (if dismissable) a close button.
func _make_header(title_text: String, variation: StringName = &"H1Label") -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", Tokens.SPACE_M)
	var title: Label = Label.new()
	title.theme_type_variation = variation
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	if dismissable:
		var close_b: SfButton = SfButton.make_icon("ui_close", "ui.overlay.close")
		close_b.pressed.connect(dismiss)
		head.add_child(close_b)
	return head


## Sizes `scroll` so `panel` is as tall as its content needs, but no taller than `max_total`
## (the rest scrolls). Returns the resulting panel height.
static func fit_scroll(p_panel: Control, scroll: ScrollContainer, content: Control, max_total: float) -> float:
	scroll.custom_minimum_size.y = 0.0
	var chrome: float = p_panel.get_combined_minimum_size().y
	var want: float = content.get_combined_minimum_size().y
	var body_h: float = clampf(want, 0.0, maxf(48.0, max_total - chrome))
	scroll.custom_minimum_size.y = body_h
	return chrome + body_h


## A vertical scroll area whose content fills its width.
static func make_scroll(content: Control) -> ScrollContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc
