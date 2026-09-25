extends RefCounted
## Sound (§8.6, §15.4, §15.5): the buses follow the settings, every sound id has a fallback, the
## fallback is deterministic, music cues are tracked and silent until delivered, and the UI kit
## makes its sounds.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_buses_follow_the_settings(t: T) -> void:
	var settings: Node = _root().get_node("Settings")
	settings.set("persist", false)
	for bus: String in ["UI", "Effects", "Music"]:
		var idx: int = AudioServer.get_bus_index(bus)
		t.ok(idx > 0, "the %s bus exists" % bus)
		t.eq(str(AudioServer.get_bus_send(idx)), "Master", "%s sends to Master" % bus)
	settings.call("set_music_volume", 0.5)
	t.near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5), 0.01, "music volume")
	settings.call("set_ui_volume", 0.0)
	t.ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "zero volume mutes the bus")
	settings.call("set_muted", true)
	t.ok(AudioServer.is_bus_mute(0), "mute silences Master, so every sound respects it")
	settings.call("set_muted", false)
	settings.call("set_ui_volume", 0.8)
	settings.call("set_music_volume", 0.7)
	t.not_ok(AudioServer.is_bus_mute(0))
	t.not_ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")))


func test_every_sound_id_has_a_fallback(t: T) -> void:
	var ids: Array[String] = []
	for id: String in Content.db().ids("assets"):
		if DictIO.str_of(Content.db().record("assets", id), "kind") == "sfx":
			ids.append(id)
	t.eq(ids.size(), 40, "the §15.4 list")
	for id2: String in ids:
		if SoundSynth.BEDS.has(id2):
			t.eq(SoundSynth.stream(id2), null, "%s is a bed: silent until delivered" % id2)
			continue
		var st: AudioStreamWAV = SoundSynth.stream(id2)
		t.ok(st != null, "%s has a fallback" % id2)
		if st == null:
			continue
		var length: float = SoundSynth.length_of(st)
		t.ok(length >= 0.02 and length <= 3.0, "%s lasts %.2f s" % [id2, length])
		var peak: float = SoundSynth.peak_of(st)
		t.ok(peak > 0.05 and peak <= SoundSynth.PEAK + 0.001, "%s peaks at %.2f" % [id2, peak])
	for id3: String in SoundSynth.RECIPES.keys():
		t.ok(ids.has(id3), "recipe %s is a §15.4 id" % id3)


func test_the_fallback_is_deterministic(t: T) -> void:
	var a: AudioStreamWAV = SoundSynth.render(SoundSynth.RECIPES["hit_explosive"], 9)
	var b: AudioStreamWAV = SoundSynth.render(SoundSynth.RECIPES["hit_explosive"], 9)
	t.ok(a.data == b.data, "the same recipe renders the same samples")


func test_music_cues_are_tracked_and_silent_until_delivered(t: T) -> void:
	var audio: Node = _root().get_node("Audio")
	audio.call("play_music", "mus_title")
	t.eq(audio.get("current_music"), "mus_title")
	t.not_ok(audio.call("is_music_playing"), "nothing plays until the track is delivered")
	audio.call("play_music", "theme_sola")
	t.eq(audio.get("current_music"), "theme_sola", "a new cue replaces the old one")
	audio.call("play_music", "")
	t.eq(audio.get("current_music"), "")


func test_the_ui_kit_makes_its_sounds(t: T) -> void:
	var audio: Node = _root().get_node("Audio")
	var b: SfButton = SfButton.make("ui.flow.back", "", SfButton.PRIMARY)
	_root().add_child(b)
	b.pressed.emit()
	t.eq(audio.get("last_sound"), "ui_confirm", "a primary button confirms")
	var tab: SfButton = SfButton.make("ui.flow.back", "", SfButton.TAB)
	_root().add_child(tab)
	tab.pressed.emit()
	t.eq(audio.get("last_sound"), "ui_toggle_on", "a tab toggles")
	b.sound = "ui_cancel"
	b.pressed.emit()
	t.eq(audio.get("last_sound"), "ui_cancel", "a button can name its sound")
	var m: Modal = Modal.make("Test")
	m.open()
	t.eq(audio.get("last_sound"), "ui_panel_open", "overlays open with a sound")
	m.close()
	t.eq(audio.get("last_sound"), "ui_panel_close")
	b.queue_free()
	tab.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
