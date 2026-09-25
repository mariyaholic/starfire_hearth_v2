class_name SoundSynth
extends RefCounted
## The fallback for every sound of §15.4 until its file is delivered: short blips synthesised
## from a recipe, soft and pitched to D major pentatonic (D E F# A B) so they sit inside the
## score. A recipe is a list of voices; a voice is a note (semitones from D4), a length, a wave
## (sine, tri, pluck, bell or noise), a gain, and optional glide, attack, envelope curve,
## noise colour ("lp" to "lp_end"), vibrato and tremolo. The same recipe always renders the same
## samples.

const MIX_RATE: int = 22050
const D4: float = 293.66
## Rendered sounds are scaled down to this peak when they would go over it.
const PEAK: float = 0.85

## §15.4 batch 2: game sounds, played on the Effects bus. Everything else is an interface sound.
const GAME_SOUNDS: Array[String] = [
	"ship_move_order", "ship_arrive", "survey_ping", "beacon_activate", "jump_transit",
	"noise_threshold", "hit_kinetic", "hit_thermal", "hit_explosive", "shield_hit", "pd_intercept",
	"ship_destroyed", "battle_won", "battle_lost", "treaty_signed", "war_declared", "vael_voice",
	"ambient_ui_room",
]
## Sounds the brief asks for in three variants (×3); the fallback varies the pitch slightly.
const VARIED: Array[String] = ["ui_click", "ui_page_turn", "ui_place_district", "hit_kinetic", "hit_thermal", "hit_explosive", "shield_hit", "vael_voice"]
## Beds rather than blips: silent until delivered, like music.
const BEDS: Array[String] = ["ambient_ui_room"]

const RECIPES: Dictionary[String, Array] = {
	"ui_click": [{"n": 12.0, "len": 0.06, "wave": "pluck", "gain": 0.5}],
	"ui_hover": [{"n": 24.0, "len": 0.03, "wave": "sine", "gain": 0.1}],
	"ui_confirm": [{"n": 12.0, "len": 0.12, "wave": "bell", "gain": 0.4}, {"at": 0.08, "n": 19.0, "len": 0.16, "wave": "bell", "gain": 0.4}],
	"ui_cancel": [{"n": 16.0, "len": 0.16, "wave": "sine", "gain": 0.35, "glide": -4.0}],
	"ui_error": [{"n": -10.0, "len": 0.1, "wave": "tri", "gain": 0.45}, {"at": 0.13, "n": -12.0, "len": 0.14, "wave": "tri", "gain": 0.45}],
	"ui_toggle_on": [{"n": 9.0, "len": 0.09, "wave": "pluck", "gain": 0.4, "glide": 3.0}],
	"ui_toggle_off": [{"n": 12.0, "len": 0.09, "wave": "pluck", "gain": 0.4, "glide": -3.0}],
	"ui_panel_open": [{"len": 0.2, "wave": "noise", "gain": 0.2, "lp": 0.05, "lp_end": 0.35, "curve": "swell"}, {"at": 0.08, "n": 28.0, "len": 0.14, "wave": "sine", "gain": 0.06}],
	"ui_panel_close": [{"len": 0.16, "wave": "noise", "gain": 0.18, "lp": 0.35, "lp_end": 0.04, "curve": "swell"}],
	"ui_tooltip_pin": [{"n": 26.0, "len": 0.06, "wave": "bell", "gain": 0.25}],
	"ui_end_turn": [{"n": -12.0, "len": 0.85, "wave": "bell", "gain": 0.55, "attack": 0.05}, {"n": -5.0, "len": 0.7, "wave": "sine", "gain": 0.18, "attack": 0.12}],
	"ui_alert": [{"n": 19.0, "len": 0.18, "wave": "bell", "gain": 0.35}, {"at": 0.15, "n": 24.0, "len": 0.25, "wave": "bell", "gain": 0.35}],
	"ui_alert_critical": [{"n": 9.0, "len": 0.2, "wave": "tri", "gain": 0.35}, {"at": 0.22, "n": 4.0, "len": 0.2, "wave": "tri", "gain": 0.35}, {"at": 0.44, "n": 9.0, "len": 0.2, "wave": "tri", "gain": 0.35}, {"at": 0.66, "n": 4.0, "len": 0.22, "wave": "tri", "gain": 0.35}],
	"ui_event_open": [{"n": 19.0, "len": 0.4, "wave": "bell", "gain": 0.25}, {"at": 0.1, "n": 21.0, "len": 0.4, "wave": "bell", "gain": 0.22}, {"at": 0.2, "n": 24.0, "len": 0.45, "wave": "bell", "gain": 0.2}, {"at": 0.3, "n": 28.0, "len": 0.45, "wave": "bell", "gain": 0.16}],
	"ui_choice_made": [{"n": 0.0, "len": 0.6, "wave": "bell", "gain": 0.3}, {"n": 4.0, "len": 0.6, "wave": "bell", "gain": 0.25}, {"n": 7.0, "len": 0.6, "wave": "bell", "gain": 0.25}],
	"ui_page_turn": [{"len": 0.22, "wave": "noise", "gain": 0.18, "lp": 0.2, "lp_end": 0.06, "curve": "swell"}],
	"ui_research_done": [{"n": 19.0, "len": 0.2, "wave": "bell", "gain": 0.35}, {"at": 0.13, "n": 24.0, "len": 0.2, "wave": "bell", "gain": 0.35}, {"at": 0.26, "n": 28.0, "len": 0.35, "wave": "bell", "gain": 0.35}],
	"ui_build_done": [{"len": 0.1, "wave": "noise", "gain": 0.35, "lp": 0.04}, {"n": -12.0, "len": 0.1, "wave": "tri", "gain": 0.3}, {"at": 0.16, "n": 19.0, "len": 0.3, "wave": "bell", "gain": 0.3}],
	"ui_place_district": [{"n": -5.0, "len": 0.16, "wave": "pluck", "gain": 0.45}, {"len": 0.05, "wave": "noise", "gain": 0.15, "lp": 0.1}],
	"ui_demolish": [{"len": 0.4, "wave": "noise", "gain": 0.45, "lp": 0.03}, {"n": -17.0, "len": 0.3, "wave": "tri", "gain": 0.25, "glide": -3.0}],
	"ui_pop_growth": [{"n": 7.0, "len": 0.3, "wave": "sine", "gain": 0.35, "glide": 5.0, "attack": 0.03}],
	"ui_overflow_warn": [{"n": 7.0, "len": 0.32, "wave": "sine", "gain": 0.3, "glide": 12.0, "trem": 0.4, "trem_rate": 18.0}],
	"ship_move_order": [{"n": 21.0, "len": 0.06, "wave": "tri", "gain": 0.25}, {"at": 0.09, "n": 21.0, "len": 0.08, "wave": "tri", "gain": 0.25}],
	"ship_arrive": [{"len": 0.3, "wave": "noise", "gain": 0.3, "lp": 0.06, "lp_end": 0.02}, {"n": -12.0, "len": 0.3, "wave": "sine", "gain": 0.3, "glide": -5.0}],
	"survey_ping": [{"n": 24.0, "len": 0.7, "wave": "sine", "gain": 0.4}, {"at": 0.28, "n": 24.0, "len": 0.5, "wave": "sine", "gain": 0.12}],
	"beacon_activate": [
		{"n": -12.0, "len": 2.2, "wave": "sine", "gain": 0.25, "attack": 0.6, "curve": "flat"},
		{"at": 0.3, "n": -5.0, "len": 1.9, "wave": "sine", "gain": 0.2, "attack": 0.5, "curve": "flat"},
		{"at": 0.6, "n": 0.0, "len": 1.6, "wave": "sine", "gain": 0.18, "attack": 0.4, "curve": "flat"},
		{"at": 0.9, "n": 4.0, "len": 1.3, "wave": "sine", "gain": 0.15, "attack": 0.3, "curve": "flat"},
		{"at": 1.2, "n": 7.0, "len": 1.0, "wave": "bell", "gain": 0.15, "attack": 0.2, "curve": "flat"},
	],
	"jump_transit": [{"len": 1.0, "wave": "noise", "gain": 0.3, "lp": 0.02, "lp_end": 0.5, "curve": "swell"}, {"n": -12.0, "len": 1.0, "wave": "sine", "gain": 0.25, "glide": 24.0, "curve": "swell"}],
	"noise_threshold": [{"n": -24.0, "len": 0.3, "wave": "sine", "gain": 0.6}, {"at": 0.35, "n": -24.0, "len": 0.45, "wave": "sine", "gain": 0.5}],
	"hit_kinetic": [{"len": 0.12, "wave": "noise", "gain": 0.4, "lp": 0.6}, {"n": 31.0, "len": 0.1, "wave": "bell", "gain": 0.15}],
	"hit_thermal": [{"len": 0.2, "wave": "noise", "gain": 0.25, "lp": 0.9, "trem": 0.6, "trem_rate": 60.0}],
	"hit_explosive": [{"len": 0.38, "wave": "noise", "gain": 0.55, "lp": 0.02}],
	"shield_hit": [{"n": 28.0, "len": 0.25, "wave": "bell", "gain": 0.25, "glide": -2.0, "trem": 0.5, "trem_rate": 30.0}],
	"pd_intercept": [{"len": 0.02, "wave": "noise", "gain": 0.35, "lp": 0.8}, {"at": 0.045, "len": 0.02, "wave": "noise", "gain": 0.35, "lp": 0.8}, {"at": 0.09, "len": 0.02, "wave": "noise", "gain": 0.35, "lp": 0.8}],
	"ship_destroyed": [{"len": 1.2, "wave": "noise", "gain": 0.5, "lp": 0.03, "lp_end": 0.01}, {"at": 0.1, "len": 0.6, "wave": "noise", "gain": 0.2, "lp": 0.5, "trem": 0.8, "trem_rate": 14.0}],
	"battle_won": [{"n": 0.0, "len": 0.25, "wave": "bell", "gain": 0.3}, {"at": 0.2, "n": 4.0, "len": 0.25, "wave": "bell", "gain": 0.3}, {"at": 0.4, "n": 7.0, "len": 0.8, "wave": "bell", "gain": 0.3}, {"at": 0.4, "n": 12.0, "len": 0.8, "wave": "bell", "gain": 0.25}],
	"battle_lost": [{"n": -5.0, "len": 0.6, "wave": "tri", "gain": 0.35, "attack": 0.03}, {"at": 0.55, "n": -12.0, "len": 0.9, "wave": "tri", "gain": 0.35, "attack": 0.03}],
	"treaty_signed": [{"n": 0.0, "len": 1.0, "wave": "bell", "gain": 0.25}, {"n": 7.0, "len": 1.0, "wave": "bell", "gain": 0.22}, {"n": 12.0, "len": 1.0, "wave": "bell", "gain": 0.2}],
	"war_declared": [{"len": 0.4, "wave": "noise", "gain": 0.5, "lp": 0.02}, {"n": -24.0, "len": 1.5, "wave": "tri", "gain": 0.3, "attack": 0.05, "curve": "flat"}],
	"vael_voice": [
		{"n": 19.0, "len": 1.2, "wave": "sine", "gain": 0.18, "vib": 0.3, "vib_rate": 5.0, "attack": 0.15, "curve": "swell"},
		{"at": 0.1, "n": 24.0, "len": 1.1, "wave": "sine", "gain": 0.15, "vib": 0.25, "vib_rate": 6.0, "attack": 0.15, "curve": "swell"},
		{"at": 0.2, "n": 28.0, "len": 1.0, "wave": "bell", "gain": 0.12, "vib": 0.2, "vib_rate": 7.0, "attack": 0.15, "curve": "swell"},
	],
}

static var _cache: Dictionary[String, AudioStreamWAV] = {}


static func has_recipe(id: String) -> bool:
	return RECIPES.has(id)


## The fallback sound for an id (cached), or null for beds and unknown ids.
static func stream(id: String) -> AudioStreamWAV:
	if not RECIPES.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = render(RECIPES[id], Rng.salt_of(id))
	return _cache[id]


## Renders a recipe to 16-bit mono PCM.
static func render(voices: Array, noise_seed: int = 1) -> AudioStreamWAV:
	var total: float = 0.0
	for v: Variant in voices:
		var d: Dictionary = v
		total = maxf(total, float(d.get("at", 0.0)) + float(d.get("len", 0.1)))
	var n: int = int((total + 0.02) * MIX_RATE)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var s: int = noise_seed & 0x7fffffff
	for v2: Variant in voices:
		_voice(buf, v2 as Dictionary, s)
		s = (s * 48271 + 11) & 0x7fffffff
	var peak: float = 0.0
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var scale: float = 1.0 if peak <= PEAK else PEAK / peak
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i2 in n:
		bytes.encode_s16(i2 * 2, int(clampf(buf[i2] * scale, -1.0, 1.0) * 32767.0))
	var out: AudioStreamWAV = AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = MIX_RATE
	out.stereo = false
	out.data = bytes
	return out


## The peak sample of a rendered stream, 0 to 1 (for tests and the preview tool).
static func peak_of(st: AudioStreamWAV) -> float:
	var peak: int = 0
	for i: int in range(0, st.data.size(), 2):
		peak = maxi(peak, absi(st.data.decode_s16(i)))
	return peak / 32767.0


static func length_of(st: AudioStreamWAV) -> float:
	return st.data.size() / 2.0 / st.mix_rate


static func _voice(buf: PackedFloat32Array, v: Dictionary, noise_seed: int) -> void:
	var start: int = int(float(v.get("at", 0.0)) * MIX_RATE)
	var length: float = maxf(0.005, float(v.get("len", 0.1)))
	var count: int = mini(int(length * MIX_RATE), buf.size() - start)
	var wave: String = str(v.get("wave", "sine"))
	var gain: float = float(v.get("gain", 0.3))
	var base_f: float = D4 * pow(2.0, float(v.get("n", 0.0)) / 12.0)
	var glide: float = float(v.get("glide", 0.0))
	var attack: float = maxf(0.001, float(v.get("attack", 0.004)))
	var curve: String = str(v.get("curve", "exp"))
	var lp0: float = float(v.get("lp", 0.3))
	var lp1: float = float(v.get("lp_end", lp0))
	var vib: float = float(v.get("vib", 0.0))
	var vib_rate: float = float(v.get("vib_rate", 5.0))
	var trem: float = float(v.get("trem", 0.0))
	var trem_rate: float = float(v.get("trem_rate", 8.0))
	# Exponential decay to 1% at the end of the note; plucks die faster.
	var k: float = 4.6 / length * (1.6 if wave == "pluck" else 1.0)
	var phase: float = 0.0
	var lp_state: float = 0.0
	var rng: int = noise_seed
	for i in count:
		var t: float = i / float(MIX_RATE)
		var x: float = t / length
		var env: float
		match curve:
			"swell":
				env = sin(PI * x)
			"flat":
				env = minf(1.0, (1.0 - x) * 6.0)
			_:
				env = exp(-k * t)
		env *= minf(1.0, t / attack) * minf(1.0, (length - t) / 0.01)
		if trem > 0.0:
			env *= 1.0 - trem * 0.5 * (1.0 + sin(TAU * trem_rate * t))
		var smp: float
		if wave == "noise":
			rng = (rng * 1103515245 + 12345) & 0x7fffffff
			var white: float = rng / float(0x3fffffff) - 1.0
			var a: float = clampf(lerpf(lp0, lp1, x), 0.005, 1.0)
			lp_state += a * (white - lp_state)
			smp = lp_state * 0.6 / sqrt(a)
		else:
			var f: float = base_f * pow(2.0, (glide * x + vib * sin(TAU * vib_rate * t)) / 12.0)
			phase += TAU * f / MIX_RATE
			match wave:
				"tri", "pluck":
					smp = 2.0 / PI * asin(sin(phase))
				"bell":
					smp = (sin(phase) + 0.45 * sin(2.0 * phase) * exp(-k * t) + 0.2 * sin(3.01 * phase) * exp(-2.0 * k * t)) / 1.4
				_:
					smp = sin(phase)
		buf[start + i] += smp * env * gain
