extends RefCounted

const Registry = preload("res://app/voice_registry.gd")


func test_platform_voice_identity_and_replacement(t: T) -> void:
	var old_persist: bool = Settings.persist
	var old_mute: bool = Settings.muted
	var old_volume: float = Settings.voice_volume
	Settings.persist = false
	Settings.set_muted(false)
	Settings.set_voice_volume(0.8)
	VoiceService.stop_utterance()
	var assets: Dictionary = Content.db().table("assets")
	var asset_id: String = "voice_platform_state_fixture"
	assets[asset_id] = {"id": asset_id, "status": "delivered", "kind": "voice", "file": "sfx/vael_voice_1.wav"}
	var playing: Dictionary = Registry.presentation_cue("platform/playing", "speaker", "event.unrest.1.body", asset_id)
	var first: Dictionary = VoiceService.request(playing)
	t.eq(first["status"], VoiceService.STATUS_PLAYING)
	t.ok(VoiceService.active_state()["active"])
	t.eq(VoiceService.active_state().get("status", ""), VoiceService.STATUS_PLAYING, "active state exposes its delivery status")
	var conflict: Dictionary = playing.duplicate(true)
	conflict["text_key"] = "event.unrest.2.body"
	var rejected: Dictionary = VoiceService.request(conflict)
	t.not_ok(rejected["ok"], "a conflicting immediate repeat must be rejected")
	t.eq(rejected["reason"], "conflicting_cue")
	t.eq(VoiceService.cue("platform/playing")["delivery_status"], VoiceService.STATUS_PLAYING)
	t.eq(Audio.voice_utterance, "platform/playing")
	var missing: Dictionary = Registry.presentation_cue("platform/missing", "speaker", "event.unrest.1.body", "no_such_voice")
	t.eq(VoiceService.request(missing)["status"], VoiceService.STATUS_MISSING)
	t.not_ok(VoiceService.active_state()["active"], "a missing replacement leaves no active speech")
	t.eq(Audio.voice_utterance, "")
	t.eq(VoiceService.cue("platform/playing")["delivery_status"], "stopped")
	VoiceService._on_voice_finished("platform/playing")
	t.eq(VoiceService.cue("platform/playing")["delivery_status"], "stopped", "late finish cannot change a stopped cue")
	var other_conflict: Dictionary = VoiceService.request(conflict)
	t.not_ok(other_conflict["ok"])
	t.eq(VoiceService.cue("platform/playing")["delivery_status"], "stopped", "conflict cannot rewrite the stored cue")
	t.eq(VoiceService.request(missing)["reason"], "already_requested", "a rejected request does not consume the refresh guard")
	VoiceService.stop_utterance()
	assets.erase(asset_id)
	Settings.set_muted(old_mute)
	Settings.set_voice_volume(old_volume)
	Settings.persist = old_persist


func test_platform_voice_malformed_step_is_safe(t: T) -> void:
	var cue: Dictionary = Registry.presentation_cue("platform/malformed", "speaker", "event.unrest.1.body")
	cue["story_step"] = [1]
	var result: Dictionary = VoiceService.request(cue)
	t.ok(result["ok"], "malformed optional step metadata falls back safely")
	t.eq(VoiceService.cue("platform/malformed")["story_step"], 0)
	VoiceService.stop_utterance()
