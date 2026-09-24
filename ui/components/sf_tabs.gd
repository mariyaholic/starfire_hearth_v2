class_name SfTabs
extends VBoxContainer
## A row of tab buttons over one visible page. The row scrolls sideways when the tabs do not fit
## (phones, 200% text), instead of squeezing labels.

signal tab_changed(index: int)

var current: int = 0
var _strip: HBoxContainer
var _pages: Array[Control] = []
var _buttons: Array[SfButton] = []
var _group: ButtonGroup = ButtonGroup.new()
var _page_host: MarginContainer


func _init() -> void:
	add_theme_constant_override("separation", Tokens.SPACE_M)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(sc)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", Tokens.SPACE_XS)
	sc.add_child(_strip)
	_page_host = MarginContainer.new()
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_page_host)


func add_tab(title_key: String, page: Control, icon_id: String = "") -> int:
	var b: SfButton = SfButton.make(title_key, icon_id, SfButton.TAB)
	b.button_group = _group
	var i: int = _buttons.size()
	b.pressed.connect(select.bind(i))
	_strip.add_child(b)
	_buttons.append(b)
	_pages.append(page)
	page.visible = false
	_page_host.add_child(page)
	if i == 0:
		select.call_deferred(0)
	return i


func select(i: int) -> void:
	if i < 0 or i >= _pages.size():
		return
	current = i
	for j in _pages.size():
		_pages[j].visible = j == i
		_buttons[j].set_pressed_no_signal(j == i)
	tab_changed.emit(i)


func tab_count() -> int:
	return _pages.size()
