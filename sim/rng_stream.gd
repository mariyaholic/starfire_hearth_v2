class_name RngStream
extends RefCounted
## One xoshiro128** generator. Create through Rng.stream(); see sim/rng.gd.

const MASK32: int = 0xFFFFFFFF
const TWO_POW_32: int = 0x100000000

var _s0: int
var _s1: int
var _s2: int
var _s3: int
## Number of 32-bit words drawn so far (diagnostics and tests).
var draws: int = 0


func _init(s0: int, s1: int, s2: int, s3: int) -> void:
	_s0 = s0 & MASK32
	_s1 = s1 & MASK32
	_s2 = s2 & MASK32
	_s3 = s3 & MASK32
	if (_s0 | _s1 | _s2 | _s3) == 0:
		_s0 = 1


func next_u32() -> int:
	var result: int = Rng.mul32(Rng.rotl32(Rng.mul32(_s1, 5), 7), 9)
	var t: int = (_s1 << 9) & MASK32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = Rng.rotl32(_s3, 11)
	draws += 1
	return result


## Uniform integer in [lo, hi], both ends inclusive. Rejection sampling keeps it unbiased.
func range(lo: int, hi: int) -> int:
	assert(hi >= lo, "RngStream.range: hi < lo")
	var n: int = hi - lo + 1
	assert(n <= TWO_POW_32, "RngStream.range: span above 2^32")
	var limit: int = (TWO_POW_32 / n) * n
	while true:
		var x: int = next_u32()
		if x < limit:
			return lo + x % n
	return lo


## True with probability bp / 10000.
func chance_bp(bp: int) -> bool:
	if bp <= 0:
		return false
	if bp >= 10000:
		return true
	return self.range(0, 9999) < bp


## Index chosen with probability proportional to weights[i]. Negative weights count as 0.
## Returns -1 when every weight is 0.
func weighted(weights: Array[int]) -> int:
	var total: int = 0
	for w: int in weights:
		total += maxi(w, 0)
	if total <= 0:
		return -1
	var r: int = self.range(0, total - 1)
	for i in weights.size():
		var w: int = maxi(weights[i], 0)
		if r < w:
			return i
		r -= w
	return weights.size() - 1


## Fisher-Yates shuffle in place.
func shuffle(items: Array) -> void:
	var i: int = items.size() - 1
	while i >= 1:
		var j: int = self.range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
		i -= 1
