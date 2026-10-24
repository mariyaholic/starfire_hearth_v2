class_name CodexScreen
extends FlowScreen
## The Codex (§6.5, §7 screen 12): search at the top; on PC the categories, the entries of the
## chosen one and the open entry side by side; on phones the categories and list, then the entry
## with a way back to the list. Links inside an entry open their target here.

var index: CodexIndex
var category: String = "mechanics"
var query: String = ""
## The open entry ("" on a phone shows the list).
var current: String = ""
var _search: LineEdit
var _body: Control


static func make(start_id: String = "") -> CodexScreen:
	var s: CodexScreen = CodexScreen.new()
	s.name = "CodexScreen"
	s.back_route = AppRoot.TITLE
	s.index = CodexIndex.build(Game.view() if Game.has_game() else null)
	if s.index.has(start_id):
		s.current = start_id
		s.category = s.index.entry(start_id).category
	return s


func build_screen() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_M)
	frame.add_child(col)
	col.add_child(header(Strings.fmt("ui.codex.title")))
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = Strings.fmt("ui.codex.search")
	_search.clear_button_enabled = true
	_search.text = query
	_search.custom_minimum_size.y = Layout.target_size()
	_search.text_changed.connect(_on_query)
	col.add_child(_search)
	_body = MarginContainer.new()
	_body.name = "Body"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	if current.is_empty() and not Layout.compact:
		var first: Array[CodexIndex.Entry] = index.in_category(category)
		if not first.is_empty():
			current = first[0].id
	_fill_body()


## Opens an entry (a link, a list item, or a start id).
func open(id: String) -> void:
	if not index.has(id):
		return
	current = id
	if query.is_empty():
		category = index.entry(id).category
	Audio.play("ui_page_turn")
	_fill_body()


func show_category(c: String) -> void:
	category = c
	query = ""
	if _search != null:
		_search.text = ""
	current = "" if Layout.compact else index.in_category(c)[0].id
	_fill_body()


func demo(state_name: String) -> void:
	if state_name.begins_with("open:"):
		open(state_name.trim_prefix("open:"))
	elif state_name.begins_with("search:"):
		_search.text = state_name.trim_prefix("search:")
		_on_query(_search.text)
	await get_tree().process_frame


func _on_query(text: String) -> void:
	query = text.strip_edges()
	if Layout.compact:
		current = ""
	_fill_body()


func _fill_body() -> void:
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	# A phone reading an entry needs the room more than the search field.
	_search.visible = not (Layout.compact and not current.is_empty())
	if Layout.compact:
		if current.is_empty():
			var v: VBoxContainer = VBoxContainer.new()
			v.add_theme_constant_override("separation", Tokens.SPACE_S)
			if query.is_empty():
				v.add_child(_categories(true))
			v.add_child(_list())
			_body.add_child(FlowScreen.scroll_of(v))
		else:
			var v2: VBoxContainer = VBoxContainer.new()
			v2.add_theme_constant_override("separation", Tokens.SPACE_S)
			var back: SfButton = SfButton.make("ui.codex.back_to_list", "ui_back", SfButton.GHOST)
			back.name = "BackToList"
			back.sound = "ui_cancel"
			back.pressed.connect(func() -> void:
				current = ""
				_fill_body())
			v2.add_child(back)
			v2.add_child(FlowScreen.scroll_of(_entry_view()))
			_body.add_child(v2)
		return
	# PC: categories, list and entry side by side while the entry keeps a readable width; with
	# large text the categories move to a row above the list and the entry.
	var three: bool = _content_width() - (230.0 + 300.0) * Settings.text_scale - 2 * Tokens.SPACE_L >= 600.0
	var host: VBoxContainer = VBoxContainer.new()
	host.add_theme_constant_override("separation", Tokens.SPACE_M)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_L)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if three:
		var cats: ScrollContainer = FlowScreen.scroll_of(_categories(false))
		cats.size_flags_horizontal = Control.SIZE_FILL
		cats.custom_minimum_size.x = 230.0 * Settings.text_scale
		row.add_child(cats)
	else:
		host.add_child(_categories(true))
	host.add_child(row)
	var list: ScrollContainer = FlowScreen.scroll_of(_list())
	list.size_flags_horizontal = Control.SIZE_FILL
	list.custom_minimum_size.x = 300.0 * Settings.text_scale
	row.add_child(list)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"Card"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(FlowScreen.scroll_of(_entry_view()))
	row.add_child(panel)
	_body.add_child(host)


## The width the frame gives its content (MAX_CONTENT_WIDTH at most).
func _content_width() -> float:
	var m: Vector4 = Layout.safe_margins
	return minf(FlowScreen.MAX_CONTENT_WIDTH, Layout.logical_size.x - m.x - m.z - 2 * Tokens.SPACE_XXL)


func _categories(flow: bool) -> Container:
	var box: Container
	if flow:
		box = HFlowContainer.new()
	else:
		box = VBoxContainer.new()
	box.name = "Categories"
	var group: ButtonGroup = ButtonGroup.new()
	for c: String in index.categories():
		var b: SfButton = SfButton.make(CodexIndex.CATEGORY_KEYS[c], "", SfButton.TAB)
		b.name = "Category_" + c
		b.button_group = group
		b.button_pressed = query.is_empty() and c == category
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(show_category.bind(c))
		box.add_child(b)
	return box


func _list() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "List"
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	var items: Array[CodexIndex.Entry] = index.search(query) if not query.is_empty() else index.in_category(category)
	if items.is_empty():
		v.add_child(FlowScreen.label(Strings.fmt("ui.codex.no_results"), &"SecondaryLabel"))
	for e: CodexIndex.Entry in items:
		var b: SfButton = SfButton.make("", e.icon if e.portrait.is_empty() else "ui_advisor", SfButton.TAB)
		b.text = e.title
		b.name = "Item_" + e.id.replace(":", "_").replace(".", "_")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_pressed = e.id == current
		b.pressed.connect(open.bind(e.id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(b)
	return v


func _entry_view() -> Control:
	var e: CodexIndex.Entry = index.entry(current)
	if e == null:
		return FlowScreen.label(Strings.fmt("ui.codex.pick"), &"SecondaryLabel")
	return CodexEntryView.make(e, index, open)
