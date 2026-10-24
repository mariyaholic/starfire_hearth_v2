extends Node
## Optional character speech is presentation state only. A cue can be registered and displayed
## with no playable clip; the written event and its choices never wait for this service.

const VoiceRegistry = preload("res://app/voice_registry.gd")

signal changed(state: Dictionary)

const STATUS_MISSING: String = "missing"
const STATUS_MUTED: String = "muted"
const STATUS_PLAYING: String = "playing"
const STATUS_FINISHED: String = "finished"
const STATUS_UNAVAILABLE: String = "unavailable"
const STATUS_KEYS: Dictionary = {
	STATUS_MISSING: "ui.voice.missing",
	STATUS_MUTED: "ui.voice.muted",
	STATUS_PLAYING: "ui.voice.playing",
	STATUS_FINISHED: "ui.voice.finished",
	STATUS_UNAVAILABLE: "ui.voice.unavailable",
}

var _registry: Dictionary[String, Dictionary] = {}
var _active: Dictionary = {}
var _last_requested_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.session_started.connect(_on_session_started)
	Audio.voice_finished.connect(_on_voice_finished)
	Settings.changed.connect(_on_setting)


## Stores stable metadata once. A later caller cannot silently redefine an utterance's speaker,
## text or asset mapping, which prevents refreshes from turning into accidental replays.
func register(cue: Dictionary) -> bool:
	var normalized: Dictionary = VoiceRegistry.normalize(cue)
	var utterance_id: String = str(normalized.get("utterance_id", ""))
	if not VoiceRegistry.valid(normalized):
		return false
	if _registry.has(utterance_id):
		var prior: Dictionary = _registry[utterance_id]
		for key: String in ["speaker", "text_key", "story_chain", "story_step", "locale", "asset_id"]:
			if prior.get(key, null) != normalized.get(key, null):
				return false
		return true
	normalized["delivery_status"] = "unrequested"
	normalized["text_available"] = Strings.has(str(normalized.get("text_key", "")))
	_registry[utterance_id] = normalized
	return true


func registry() -> Dictionary:
	return _registry.duplicate(true)


func cue(utterance_id: String) -> Dictionary:
	return _registry.get(utterance_id, {}).duplicate(true)


## Requests optional speech for a cue. A repeated request for the same stable ID is ignored, so
## ordinary overlay/UI refreshes cannot restart the line. A new ID replaces the old line first.
func play_utterance(raw_cue: Dictionary) -> Dictionary:
	var normalized: Dictionary = VoiceRegistry.normalize(raw_cue)
	var utterance_id: String = str(normalized.get("utterance_id", ""))
	if not VoiceRegistry.valid(normalized):
		return {"ok": false, "played": false, "status": STATUS_UNAVAILABLE, "reason": "invalid_cue", "utterance_id": utterance_id}
	if utterance_id == _last_requested_id:
		return {"ok": true, "played": false, "status": str(_registry.get(utterance_id, {}).get("delivery_status", STATUS_UNAVAILABLE)), "reason": "already_requested", "utterance_id": utterance_id}
	_last_requested_id = utterance_id
	if not register(normalized):
		_set_status(normalized, STATUS_UNAVAILABLE)
		return {"ok": false, "played": false, "status": STATUS_UNAVAILABLE, "reason": "conflicting_cue", "utterance_id": utterance_id}
	_stop_audio_only()
	if Settings.muted or Settings.voice_volume <= 0.0:
		_set_status(normalized, STATUS_MUTED)
		return {"ok": true, "played": false, "status": STATUS_MUTED, "reason": "voice_muted", "utterance_id": utterance_id}
	var asset_id: String = str(normalized.get("asset_id", ""))
	var stream: AudioStream = AssetIds.voice_stream(asset_id) if not asset_id.is_empty() else null
	if stream == null:
		_set_status(normalized, STATUS_MISSING)
		return {"ok": true, "played": false, "status": STATUS_MISSING, "reason": "optional_clip_unavailable", "utterance_id": utterance_id}
	if not Audio.play_voice(utterance_id, stream):
		_set_status(normalized, STATUS_UNAVAILABLE)
		return {"ok": true, "played": false, "status": STATUS_UNAVAILABLE, "reason": "voice_backend_unavailable", "utterance_id": utterance_id}
	_active = normalized.duplicate(true)
	_set_status(normalized, STATUS_PLAYING)
	return {"ok": true, "played": true, "status": STATUS_PLAYING, "reason": "played", "utterance_id": utterance_id}


## Alias used by overlays and presentation tests.
func request(cue: Dictionary) -> Dictionary:
	return play_utterance(cue)


func stop_utterance() -> void:
	_stop_audio_only()
	_active.clear()
	_last_requested_id = ""
	changed.emit({"active": false, "status": "stopped"})


func active_state() -> Dictionary:
	if _active.is_empty():
		return {"active": false, "utterance_id": "", "status": "stopped"}
	var out: Dictionary = _active.duplicate(true)
	out["active"] = true
	return out


## Localization remains independent from audio delivery. Strings.fmt intentionally returns the key
## when a locale entry is absent, preserving visible dialogue and choices for every cue.
func text_for(cue: Dictionary, args: Dictionary = {}) -> String:
	return Strings.fmt(str(cue.get("text_key", "")), args)


func status_text(status: String) -> String:
	return Strings.fmt(str(STATUS_KEYS.get(status, "ui.voice.unavailable")))


func _stop_audio_only() -> void:
	if not _active.is_empty():
		_set_status(_active, "stopped")
	Audio.stop_voice()


func _set_status(cue: Dictionary, status: String) -> void:
	var id: String = str(cue.get("utterance_id", ""))
	if id.is_empty() or not _registry.has(id):
		return
	_registry[id]["delivery_status"] = status
	var state: Dictionary = _registry[id].duplicate(true)
	state["active"] = id == str(_active.get("utterance_id", "")) and status == STATUS_PLAYING
	changed.emit(state)


func _on_voice_finished(utterance_id: String) -> void:
	if str(_active.get("utterance_id", "")) != utterance_id:
		return
	var finished: Dictionary = _active.duplicate(true)
	_active.clear()
	_set_status(finished, STATUS_FINISHED)
	# Keep _last_requested_id until the scope closes; an ordinary refresh must not replay it.


func _on_session_started() -> void:
	stop_utterance()


func _on_setting(key: String) -> void:
	if key in ["muted", "voice_volume"] and (Settings.muted or Settings.voice_volume <= 0.0):
		stop_utterance()
