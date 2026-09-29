class_name LoadScreen
extends FlowScreen
## Load game (§7 screen 13): every save, newest first, with its thumbnail, scenario, date and kind
## (auto-save, checkpoint or manual). Loading opens the game where the save left it; a save that
## cannot be read says why instead of failing quietly.

const KIND_KEYS: Dictionary[String, String] = {
	"auto": "ui.load.kind_auto", "checkpoint": "ui.load.kind_checkpoint", "manual": "ui.load.kind_manual",
}


static func make(p_back: String = AppRoot.TITLE) -> LoadScreen:
	var s: LoadScreen = LoadScreen.new()
	s.name = "LoadScreen"
	s.back_route = p_back
	return s


func build_screen() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	col.add_child(header(Strings.fmt("ui.load.title")))
	var list: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	list.name = "Saves"
	var saves: Array[Dictionary] = SaveService.list_saves()
	if saves.is_empty():
		list.add_child(FlowScreen.label(Strings.fmt("ui.load.none"), &"SecondaryLabel"))
	for sv: Dictionary in saves:
		list.add_child(_card(sv))
	col.add_child(FlowScreen.scroll_of(list))


func _card(sv: Dictionary) -> Control:
	var slot: String = sv["slot"]
	var kind: String = sv["kind"]
	var scenario: Dictionary = Content.db().scenarios.get(str(sv["scenario_id"]), {})
	var card: Card = Card.make(Strings.fmt(DictIO.str_of(scenario, "name_key", "ui.title.unknown_scenario")), Strings.fmt(KIND_KEYS.get(kind, "ui.load.kind_manual")), "ui_load", "accent.teal")
	card.name = "Save_" + slot
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_L)
	var thumb: String = sv["thumbnail"]
	if not thumb.is_empty():
		var img: Image = Image.load_from_file(thumb)
		if img != null:
			var tr: TextureRect = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(160, 90)
			row.add_child(tr)
	var when: Label = FlowScreen.label(Strings.fmt("ui.load.when", {"date": Fmt.date(int(sv["turn"])), "saved": Time.get_datetime_string_from_unix_time(int(sv["modified"]), true)}), &"SecondaryLabel")
	when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(GameUI.exempt(when, "the save's date and time"))
	card.add_body(row)
	var load_b: SfButton = SfButton.make("ui.load.load", "ui_play", SfButton.PRIMARY)
	load_b.name = "Load"
	load_b.pressed.connect(_load.bind(slot))
	card.add_action(load_b)
	var del: SfButton = SfButton.make("ui.load.delete", "ui_demolish", SfButton.DANGER)
	del.name = "Delete"
	del.pressed.connect(_delete.bind(slot))
	card.add_action(del)
	return card


func _load(slot: String) -> void:
	var lr: SaveSerializer.LoadResult = SaveService.load_slot(slot)
	if not lr.ok:
		Overlay.toast(Strings.fmt(lr.error_key), ReportItem.SEVERITY_WARNING)
		return
	go(AppRoot.CONTINUE, {"state": lr.state})


func _delete(slot: String) -> void:
	SaveService.delete(slot)
	_queue_rebuild()
