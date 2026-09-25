extends Node
## Sound (§8.6, §15.4, §15.5): the UI, Effects and Music buses under Master, their volumes and
## mute from Settings, sounds by §15.4 id, and music cues that crossfade. A delivered file plays
## when data/asset_manifest.json has one; until then every sound is a synthesised blip
## (SoundSynth) and every music cue is silence, though the cue is still tracked so the right
## track starts the moment it is delivered.

signal music_changed(id: String)

const BUS_UI: String = "UI"
const BUS_EFFECTS: String = "Effects"
const BUS_MUSIC: String = "Music"
const VOICES: int = 6
const CROSSFADE: float = 1.2
## The same sound asked for again within this many milliseconds plays once.
const REPEAT_MS: int = 45
const SILENT_DB: float = -60.0

## The music cue last asked for ("" for none), delivered or not.
var current_music: String = ""
## The delivered track of that cue, or null while it waits in silence.
var current_stream: AudioStream = null
## The last sound asked for and how many have played: for tests and the preview tool.
var last_sound: String = ""
var sounds_played: int = 0
var _ui: Array[AudioStreamPlayer] = []
var _fx: Array[AudioStreamPlayer] = []
var _next_ui: int = 0
var _next_fx: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_on: int = 0
var _delivered: Dictionary[String, Array] = {}
var _synth: Dictionary[String, AudioStream] = {}
var _last_at: Dictionary[String, int] = {}
var _fade: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in VOICES:
		_ui.append(_player(BUS_UI))
		_fx.append(_player(BUS_EFFECTS))
	for i in 2:
		var m: AudioStreamPlayer = _player(BUS_MUSIC)
		m.volume_db = SILENT_DB
		_music.append(m)
	Settings.changed.connect(_on_setting)
	Game.turn_resolved.connect(func(_r: TurnResult) -> void: play("ui_end_turn"))
	apply_volumes()


## Plays a §15.4 sound: the delivered file (a random variant if there are several), or its
## synthesised fallback. Unknown ids and beds without a file are silent.
func play(id: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - int(_last_at.get(id, -100000)) < REPEAT_MS:
		return
	_last_at[id] = now
	var st: AudioStream = _stream_for(id)
	if st == null:
		return
	var p: AudioStreamPlayer
	if SoundSynth.GAME_SOUNDS.has(id):
		p = _fx[_next_fx]
		_next_fx = (_next_fx + 1) % _fx.size()
	else:
		p = _ui[_next_ui]
		_next_ui = (_next_ui + 1) % _ui.size()
	last_sound = id
	sounds_played += 1
	# Headless runs (tests, tools) have no audio output; the choice above is all they check.
	if DisplayServer.get_name() == "headless":
		return
	p.stream = st
	p.pitch_scale = 1.0 + (randf() - 0.5) * 0.06 if SoundSynth.VARIED.has(id) and not AssetIds.is_delivered(id) else 1.0
	p.play()


## Crossfades to a music cue (§15.5; "" fades to silence). A cue that is not delivered yet fades
## out whatever plays and waits in silence. Stings play once; everything else loops.
func play_music(id: String) -> void:
	if id == current_music:
		return
	current_music = id
	music_changed.emit(id)
	var streams: Array = _delivered_streams(id) if not id.is_empty() else []
	current_stream = streams[0] if not streams.is_empty() else null
	var old: AudioStreamPlayer = _music[_music_on]
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not old.playing and streams.is_empty():
		return
	_fade = create_tween()
	_fade.set_parallel(true)
	if old.playing:
		_fade.tween_property(old, "volume_db", SILENT_DB, CROSSFADE)
	if not streams.is_empty():
		_music_on = 1 - _music_on
		var nxt: AudioStreamPlayer = _music[_music_on]
		var st: AudioStream = streams[0]
		if "loop" in st:
			st.set("loop", not id.begins_with("sting_"))
		nxt.stream = st
		nxt.volume_db = SILENT_DB
		# Headless runs (tests, tools) have no audio output: the track is chosen but not started.
		if DisplayServer.get_name() != "headless":
			nxt.play()
		_fade.tween_property(nxt, "volume_db", 0.0, CROSSFADE)
	_fade.chain().tween_callback(_stop_faded)


## Stops everything on the way out, so no playback is left alive in the audio server at exit.
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _ui + _fx + _music:
		p.stop()
		p.stream = null


func is_music_playing() -> bool:
	for m: AudioStreamPlayer in _music:
		if m.playing:
			return true
	return false


## Bus volumes and mute from Settings; mute silences the Master bus, so every sound respects it.
func apply_volumes() -> void:
	_set_bus(BUS_UI, Settings.ui_volume)
	_set_bus(BUS_EFFECTS, Settings.effects_volume)
	_set_bus(BUS_MUSIC, Settings.music_volume)
	AudioServer.set_bus_mute(0, Settings.muted)


func _stream_for(id: String) -> AudioStream:
	var delivered: Array = _delivered_streams(id)
	if not delivered.is_empty():
		return delivered[randi() % delivered.size()]
	if not _synth.has(id):
		_synth[id] = SoundSynth.stream(id)
	return _synth[id]


func _delivered_streams(id: String) -> Array:
	if not _delivered.has(id):
		_delivered[id] = AssetIds.streams(id)
	return _delivered[id]


func _stop_faded() -> void:
	for i in _music.size():
		if i != _music_on or current_music.is_empty() or _delivered_streams(current_music).is_empty():
			_music[i].stop()


func _player(bus: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_buses() -> void:
	for bus_name: String in [BUS_UI, BUS_EFFECTS, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _set_bus(bus_name: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.0)


func _on_setting(key: String) -> void:
	if key in ["ui_volume", "effects_volume", "music_volume", "muted"]:
		apply_volumes()
