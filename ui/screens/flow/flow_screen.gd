class_name FlowScreen
extends Control
## Base of the full-screen flow screens (title, campaign, briefing, debrief; §7 screens 1, 2 and
## 15): a background, a frame inside the safe area, and a rebuild whenever the layout class, text
## size or contrast changes. Subclasses fill `frame` in build_screen(). A screen asks to move on by
## emitting `navigate`; the AppRoot owns the routing and the campaign progress.

signal navigate(route: String, args: Dictionary)

## On wide screens the content stays this wide (logical px), centred, so lines stay readable.
const MAX_CONTENT_WIDTH: float = 1440.0

var frame: MarginContainer
## Where Esc (and the Back button) lead, or "" when the screen has no way back.
var back_route: String = ""
var _bg: ColorRect
var _rebuild_queued: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	var backdrop: Control = make_backdrop()
	if backdrop != null:
		backdrop.name = "Backdrop"
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)
	frame = MarginContainer.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	Layout.changed.connect(_queue_rebuild)
	_rebuild()


## Something drawn behind the frame (the title's sky), or null.
func make_backdrop() -> Control:
	return null


## Fills `frame`; called again after every layout change.
func build_screen() -> void:
	pass


## Puts the screen in a named state for tests and the screenshot tour.
func demo(_state_name: String) -> void:
	await get_tree().process_frame


func go(route: String, args: Dictionary = {}) -> void:
	navigate.emit(route, args)


## The screen's heading row: a Back button (when there is a way back), the title, and any actions
## (phones put a screen's main buttons here to leave more room for the content).
func header(title_text: String, kicker_text: String = "", actions: Array[Control] = []) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	if not back_route.is_empty():
		var back: SfButton = SfButton.make_icon("ui_back", "ui.flow.back", SfButton.GHOST) if Layout.compact else SfButton.make("ui.flow.back", "ui_back", SfButton.GHOST)
		back.name = "Back"
		back.sound = "ui_cancel"
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(go.bind(back_route))
		row.add_child(back)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not kicker_text.is_empty():
		texts.add_child(label(kicker_text, &"CaptionLabel"))
	var t: Label = label(title_text, &"H1Label")
	t.name = "Title"
	texts.add_child(t)
	row.add_child(texts)
	for a: Control in actions:
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(a)
	return row


## A wrapping label.
static func label(text: String, variation: StringName = &"") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A translucent panel that keeps text readable over the title's sky.
static func scrim(inner: Control) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = "Scrim"
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Tokens.color("bg.deep"), 0.82)
	box.set_corner_radius_all(Tokens.RADIUS_PANEL * 2)
	box.set_content_margin_all(Tokens.SPACE_L if Layout.compact else Tokens.SPACE_XL)
	p.add_theme_stylebox_override("panel", box)
	p.add_child(inner)
	return p


## A vertical scroll area that fills the space left in its column.
static func scroll_of(content: Control) -> ScrollContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _unhandled_input(event: InputEvent) -> void:
	if back_route.is_empty() or not event.is_action_pressed("ui_cancel"):
		return
	# Open overlays and tooltips take Esc first (the Overlay closes them).
	if Overlay.stack_size() > 0 or not Overlay.open_tooltips().is_empty():
		return
	get_viewport().set_input_as_handled()
	go(back_route)


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	_bg.color = Tokens.color("bg.deep")
	var m: Vector4 = Layout.safe_margins
	var pad: int = Tokens.SPACE_L if Layout.compact else Tokens.SPACE_XXL
	var pad_v: int = Tokens.SPACE_S if Layout.compact else Tokens.SPACE_XL
	var room: float = Layout.logical_size.x - m.x - m.z - 2 * pad
	var extra: int = maxi(0, int((room - MAX_CONTENT_WIDTH) / 2.0))
	frame.add_theme_constant_override("margin_left", pad + extra + int(m.x))
	frame.add_theme_constant_override("margin_top", pad_v + int(m.y))
	frame.add_theme_constant_override("margin_right", pad + extra + int(m.z))
	frame.add_theme_constant_override("margin_bottom", pad_v + int(m.w))
	for c: Node in frame.get_children():
		frame.remove_child(c)
		c.queue_free()
	build_screen()
