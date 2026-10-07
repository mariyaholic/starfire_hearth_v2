extends RefCounted
## Optional character voice is presentation-only: stable metadata, no synthetic speech fallback,
## and cancellation must never alter the written event or its choices.

const VoiceRegistry = preload("res://app/voice_registry.gd")


func test_registry_is_stable_and_localization_falls_back_to_key(t: T) -> void:
	var cue: Dictionary = VoiceRegistry.presentation_cue(
		"test/voice/stable", "archivist_sola", "event.unrest.1.body", "voice_missing_fixture")
	t.eq(cue["utterance_id"], "test/voice/stable")
	t.eq(cue["asset_id"], "voice_missing_fixture")
	t.ok(VoiceService.register(cue), "a presentation cue registers")
	t.ok(VoiceService.register(cue), "the identical cue is idempotent")
	var conflict: Dictionary = cue.duplicate(true)
	conflict["asset_id"] = "voice_other_fixture"
	t.not_ok(VoiceService.register(conflict), "a stable utterance cannot be redefined on refresh")
	t.eq(VoiceService.text_for(cue), Strings.fmt("event.unrest.1.body"))
	var fallback: Dictionary = cue.duplicate(true)
	fallback["text_key"] = "ui.voice.key_that_does_not_exist"
	t.eq(VoiceService.text_for(fallback), "ui.voice.key_that_does_not_exist", "missing locale text remains a visible key fallback")


func test_missing_and_muted_voice_never_blocks_written_dialogue(t: T) -> void:
	VoiceService.stop_utterance()
	var old_mute: bool = Settings.muted
	var old_volume: float = Settings.voice_volume
	var old_persist: bool = Settings.persist
	Settings.persist = false
	Settings.set_muted(false)
	Settings.set_voice_volume(0.8)
	var cue: Dictionary = VoiceRegistry.presentation_cue(
		"test/voice/missing", "steward_varga", "event.unrest.1.body", "voice_not_in_manifest")
	var before_sound_count: int = Audio.sounds_played
	var missing: Dictionary = VoiceService.request(cue)
	t.ok(missing["ok"])
	t.not_ok(missing["played"], "absent speech is silently unavailable")
	t.eq(missing["status"], VoiceService.STATUS_MISSING)
	t.eq(Audio.voice_utterance, "")
	t.eq(Audio.sounds_played, before_sound_count, "speech does not call the effects/synth fallback")
	t.empty(AssetIds.voice_streams("vael_voice"), "an ordinary SFX cannot be treated as character speech")
	var repeated: Dictionary = VoiceService.request(cue)
	t.eq(repeated["reason"], "already_requested", "a refresh does not replay the same absent cue")
	Settings.set_muted(true)
	var muted: Dictionary = VoiceService.request(VoiceRegistry.presentation_cue(
		"test/voice/muted", "steward_varga", "event.unrest.1.body", "voice_muted_fixture"))
	t.eq(muted["status"], VoiceService.STATUS_MUTED)
	t.eq(Audio.voice_utterance, "")
	Settings.set_muted(old_mute)
	Settings.set_voice_volume(old_volume)
	Settings.persist = old_persist
	VoiceService.stop_utterance()


func test_voice_bus_replaces_and_session_stop_cancels_playback(t: T) -> void:
	var idx: int = AudioServer.get_bus_index(Audio.BUS_VOICE)
	t.ok(idx > 0, "Voice is a dedicated bus")
	t.eq(str(AudioServer.get_bus_send(idx)), "Master")
	var first: AudioStream = AudioStreamWAV.new()
	var second: AudioStream = AudioStreamWAV.new()
	t.ok(Audio.play_voice("test/voice/one", first))
	t.eq(Audio.voice_utterance, "test/voice/one")
	t.ok(Audio.play_voice("test/voice/two", second), "a replacement cue is accepted")
	t.eq(Audio.voice_utterance, "test/voice/two", "replacement stops the obsolete line")
	VoiceService._on_session_started()
	t.eq(Audio.voice_utterance, "", "a load/session boundary stops optional speech")
	t.not_ok(Audio.is_voice_playing())
