extends RefCounted
var tree: SceneTree
var app: AppRoot

func _start(phone: bool = false, scale: float = 1.0) -> void:
	tree = Engine.get_main_loop()
	Settings.persist = false
	Settings.set_text_scale(scale)
	Settings.set_ui_scale(1.0)
	Settings.set_appearance("strategic")
	Settings.set_view_mode("command")
	tree.root.size = Vector2i(2400,1080) if phone else Vector2i(1600,900)
	Layout.set_profile(Layout.Profile.PHONE if phone else Layout.Profile.PC)
	await _frames()
	app = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	tree.root.add_child(app)
	await _frames()

func _frames() -> void:
	for i: int in 6: await tree.process_frame

func _stop() -> void:
	Overlay.close_all()
	app.queue_free()
	await _frames()
	Settings.set_text_scale(1.0)
	Layout.set_profile(Layout.Profile.AUTO)

func test_settings_scroll_keeps_sound_and_play_reachable_with_one_contrast_control(t: T) -> void:
	await _start()
	app.go(AppRoot.SETTINGS); await _frames()
	var sound: Control = app.screen.find_child("SoundCard", true, false)
	var play: Control = app.screen.find_child("PlayCard", true, false)
	var sound_at: Vector2 = sound.global_position
	var play_at: Vector2 = play.global_position
	var display: Control = app.screen.find_child("DisplayCard", true, false)
	var sc: ScrollContainer = display.get_parent().get_parent()
	sc.scroll_vertical = 450; await _frames()
	t.eq(sound.global_position, sound_at)
	t.eq(play.global_position, play_at)
	t.ok(display.global_position.y < 0.0, "Display scrolls independently")
	t.ok(app.screen.find_child("Toggle_high_contrast", true, false) != null)
	t.ok(app.screen.find_child("InterfaceHighContrast", true, false) == null, "Settings has one contrast control")
	await _stop()

func test_large_text_slider_labels_fit_and_tracks_align(t: T) -> void:
	await _start(false, 2.0)
	app.go(AppRoot.SETTINGS); await _frames()
	var text: HSlider = app.screen.find_child("Slider_text_size", true, false)
	var size: HSlider = app.screen.find_child("Slider_ui_scale", true, false)
	t.near(text.global_position.x, size.global_position.x, 0.1)
	t.near(text.size.x, size.size.x, 0.1)
	var labels: Array[Node] = app.screen.find_children("*", "Label", true, false)
	for node: Label in labels:
		if node.text == Strings.fmt("ui.settings.ui_scale"):
			t.eq(node.get_line_count(), 1, "Interface size fits at 200%")
	await _stop()

func test_phone_codex_categories_stay_below_search_while_entries_scroll(t: T) -> void:
	await _start(true)
	app.go(AppRoot.CODEX); await _frames()
	var search: Control = app.screen.find_child("Search", true, false)
	var categories: Control = app.screen.find_child("Categories", true, false)
	var list: Control = app.screen.find_child("List", true, false)
	var sc: ScrollContainer = list.get_parent()
	var before: Vector2 = categories.global_position
	sc.scroll_vertical = 160; await _frames()
	t.eq(categories.global_position, before, "category strip does not scroll under Search")
	t.ok(categories.global_position.y >= search.get_global_rect().end.y)
	var y: float = categories.get_child(0).position.y
	for child: Control in categories.get_children(): t.eq(child.position.y, y, "all categories share one row")
	var tabs: ScrollContainer = categories.get_parent()
	t.not_ok(tabs.get_v_scroll_bar().visible)
	t.ok(tabs.get_h_scroll_bar().max_value > tabs.size.x, "overflow categories are horizontally reachable")
	(categories.get_child(categories.get_child_count() - 1) as Button).pressed.emit()
	await _frames()
	t.eq((app.screen as CodexScreen).category, "people")
	await _stop()

func test_scale_drag_applies_once_released_and_rebuilds(t: T) -> void:
	await _start()
	app.go(AppRoot.SETTINGS); await _frames()
	var slider: HSlider = app.screen.find_child("Slider_text_size", true, false)
	slider.drag_started.emit(); slider.value = 1.35
	t.near(Settings.text_scale, 1.0, 0.001, "layout stays stable during the drag")
	slider.drag_ended.emit(true); await _frames()
	t.near(Settings.text_scale, 1.35, 0.001, "release applies the chosen scale")
	var rebuilt: HSlider = app.screen.find_child("Slider_text_size", true, false)
	t.near(rebuilt.value, 1.35, 0.001, "rebuilt controls reflect the setting")
	await _stop()

func test_compact_codex_search_open_back_and_category(t: T) -> void:
	await _start(true)
	app.go(AppRoot.CODEX); await _frames()
	var codex: CodexScreen = app.screen
	var entry: CodexIndex.Entry = codex.index.in_category("mechanics")[0]
	var search: LineEdit = codex.find_child("Search", true, false)
	search.text = entry.title; search.text_changed.emit(entry.title); await _frames()
	t.eq(codex.query, entry.title.strip_edges())
	t.ok(codex.find_child("Categories", true, false) == null, "search results take the list space")
	codex.open(entry.id); await _frames()
	t.eq(codex.current, entry.id); t.not_ok(search.visible)
	(codex.find_child("BackToList", true, false) as Button).pressed.emit(); await _frames()
	t.eq(codex.current, ""); t.ok(search.visible); t.eq(codex.query, entry.title.strip_edges())
	codex.show_category("people"); await _frames()
	t.eq(codex.query, ""); t.eq(codex.category, "people")
	t.ok(codex.find_child("Categories", true, false) != null)
	await _stop()

func test_title_keeps_nonbreaking_phrase_together_at_large_text(t: T) -> void:
	for scale: float in [1.85, 2.0]:
		await _start(false, scale)
		var tag: Label = app.screen.find_child("Tagline", true, false)
		var original: String = Strings.fmt("ui.title.tagline")
		t.ok(tag.text.contains("\n"), "long tagline is wrapped deliberately")
		t.eq(tag.text.replace("\n", " "), original, "wrap preserves the localized text")
		t.ok(tag.text.ends_with("Long\u00a0Silence"), "nonbreaking phrase stays on one line")
		var font: Font = tag.get_theme_font("font")
		for line: String in tag.text.split("\n"):
			t.ok(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.get_theme_font_size("font_size")).x <= tag.size.x, "wrapped lines fit the title block")
		await _stop()
