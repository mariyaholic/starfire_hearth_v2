class_name Rng
extends RefCounted
## Deterministic random streams for the simulation.
##
## Algorithm: xoshiro128** over 32-bit words held in 64-bit ints, every result masked with
## MASK32. Multiplication goes through mul32() so no intermediate exceeds 2^63.
## Each stream is derived statelessly from (game_seed, turn, stream id, salt): the four inputs are
## folded with fmix32 and mul32 into one key, and splitmix32 expands the key into the four state
## words. Nothing about RNG needs to be saved.
##
## Never use Godot's global randi()/randf() or the engine's hash() in simulation code.

const MASK32: int = 0xFFFFFFFF

## Stream ids. FORECAST is for battle forecasts and must never affect state.
const GEN: int = 1
const COMBAT: int = 2
const EVENTS: int = 3
const AI: int = 4
const RESEARCH: int = 5
const GROWTH: int = 6
const FORECAST: int = 7

const STREAM_NAMES: Dictionary[int, String] = {
	GEN: "gen", COMBAT: "combat", EVENTS: "events", AI: "ai",
	RESEARCH: "research", GROWTH: "growth", FORECAST: "forecast",
}


## Returns a fresh stream for (game_seed, turn, stream_id, salt).
static func stream(game_seed: int, turn: int, stream_id: int, salt: int = 0) -> RngStream:
	var key: int = game_seed & MASK32
	key = fmix32(key ^ mul32(turn & MASK32, 0x9E3779B1))
	key = fmix32(key ^ mul32(stream_id & MASK32, 0x85EBCA77))
	key = fmix32(key ^ mul32(salt & MASK32, 0xC2B2AE3D))
	var sm: int = key
	var words: Array[int] = []
	for i in 4:
		sm = (sm + 0x9E3779B9) & MASK32
		var z: int = sm
		z = mul32(z ^ (z >> 16), 0x85EBCA6B)
		z = mul32(z ^ (z >> 13), 0xC2B2AE35)
		words.append(z ^ (z >> 16))
	return RngStream.new(words[0], words[1], words[2], words[3])


## (a * b) mod 2^32 for a, b in [0, 2^32). b is split into 16-bit halves so that the largest
## intermediate is below 2^48.
static func mul32(a: int, b: int) -> int:
	var lo: int = a * (b & 0xFFFF)
	var hi: int = ((a * ((b >> 16) & 0xFFFF)) & 0xFFFF) << 16
	return (lo + hi) & MASK32


static func rotl32(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK32


## MurmurHash3 32-bit finaliser.
static func fmix32(h: int) -> int:
	h &= MASK32
	h ^= h >> 16
	h = mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return h


## Stable 32-bit salt for a string (FNV-1a over UTF-8). Use it to seed per-entity streams,
## e.g. combat in one system: Rng.stream(seed, turn, Rng.COMBAT, Rng.salt_of(system_id)).
static func salt_of(text: String) -> int:
	var h: int = 0x811C9DC5
	for b: int in text.to_utf8_buffer():
		h ^= b
		h = mul32(h, 0x01000193)
	return h
