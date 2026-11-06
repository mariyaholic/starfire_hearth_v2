extends RefCounted
## Status listeners can replace or cancel speech synchronously. The newest accepted
## operation owns the service, audio player, and repeated-request guard together.

const Registry = preload("res://app/voice_registry.gd")
const ASSET: String = "voice_independent_lifecycle_fixture"

func _prepare() -> Dictionary:
	var before: Dictionary = {"persist": Settings.persist, "muted": Settings.muted, "volume": Settings.voice_volume}
	Settings.persist = false
	Settings.set_muted(false)
	Settings.set_voice_volume(0.8)
	VoiceService.stop_utterance()
	Content.db().table("assets")[ASSET] = {"id": ASSET, "status": "delivered", "kind": "voice", "file": "sfx/vael_voice_1.wav"}
	return before

func _restore(before: Dictionary) -> void:
	VoiceService.stop_utterance()
	Content.db().table("assets").erase(ASSET)
	Settings.set_muted(before["muted"])
	Settings.set_voice_volume(before["volume"])
	Settings.persist = before["persist"]

func _cue(id: String) -> Dictionary:
	return Registry.presentation_cue("independent/" + id, "speaker", "event.unrest.1.body", ASSET)

func test_stop_callback_can_request_new_speech(t: T) -> void:
	var before: Dictionary = _prepare()
	var first: Dictionary = _cue("stop_first")
	var replacement: Dictionary = _cue("stop_replacement")
	VoiceService.request(first)
	var updates: Array[Dictionary] = []
	var observe: Callable = func(update: Dictionary) -> void:
		updates.append(update)
		if update.get("utterance_id", "") == first["utterance_id"] and update.get("delivery_status", "") == "stopped":
			VoiceService.request(replacement)
	VoiceService.changed.connect(observe)
	VoiceService.stop_utterance()
	VoiceService.changed.disconnect(observe)
	t.eq(VoiceService.active_state()["utterance_id"], replacement["utterance_id"], "new speech survives the old stop callback")
	t.eq(Audio.voice_utterance, replacement["utterance_id"], "audio agrees with active speech")
	t.eq(updates[-1].get("delivery_status", ""), VoiceService.STATUS_PLAYING, "old stop cannot announce stale global inactivity")
	t.eq(VoiceService.request(replacement)["reason"], "already_requested", "new speech retains its repeated-request guard")
	_restore(before)

func test_replacement_callback_owns_the_latest_request(t: T) -> void:
	var before: Dictionary = _prepare()
	var first: Dictionary = _cue("replace_first")
	var interrupted: Dictionary = _cue("replace_interrupted")
	var newest: Dictionary = _cue("replace_newest")
	VoiceService.request(first)
	var observe: Callable = func(update: Dictionary) -> void:
		if update.get("utterance_id", "") == first["utterance_id"] and update.get("delivery_status", "") == "stopped":
			VoiceService.request(newest)
	VoiceService.changed.connect(observe)
	var result: Dictionary = VoiceService.request(interrupted)
	VoiceService.changed.disconnect(observe)
	t.not_ok(result["played"], "interrupted request never starts its audio")
	t.eq(result["reason"], "superseded")
	t.eq(VoiceService.active_state()["utterance_id"], newest["utterance_id"])
	t.eq(Audio.voice_utterance, newest["utterance_id"])
	t.eq(VoiceService.request(newest)["reason"], "already_requested")
	_restore(before)

func test_replacement_callback_can_cancel_pending_speech(t: T) -> void:
	var before: Dictionary = _prepare()
	var first: Dictionary = _cue("cancel_first")
	VoiceService.request(first)
	var observe: Callable = func(update: Dictionary) -> void:
		if update.get("utterance_id", "") == first["utterance_id"] and update.get("delivery_status", "") == "stopped":
			VoiceService.stop_utterance()
	VoiceService.changed.connect(observe)
	var result: Dictionary = VoiceService.request(_cue("cancel_pending"))
	VoiceService.changed.disconnect(observe)
	t.not_ok(result["played"])
	t.eq(result["reason"], "superseded")
	t.not_ok(VoiceService.active_state()["active"], "scope closure during replacement leaves no active speech")
	t.eq(Audio.voice_utterance, "")
	_restore(before)
