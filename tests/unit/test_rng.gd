extends RefCounted
## Deterministic RNG behaviour beyond the golden vectors.


func test_mul32_wraps_like_uint32(t: T) -> void:
	t.eq(Rng.mul32(0xFFFFFFFF, 0xFFFFFFFF), 1, "(2^32-1)^2 mod 2^32")
	t.eq(Rng.mul32(0x10000, 0x10000), 0, "2^32 mod 2^32")
	t.eq(Rng.mul32(123456789, 987654321), (123456789 * 987654321) & 0xFFFFFFFF)
	t.eq(Rng.mul32(0, 0xFFFFFFFF), 0)


func test_rotl32(t: T) -> void:
	t.eq(Rng.rotl32(0x80000001, 1), 0x00000003)
	t.eq(Rng.rotl32(0x12345678, 8), 0x34567812)


func test_same_inputs_same_sequence(t: T) -> void:
	var a: RngStream = Rng.stream(77, 12, Rng.COMBAT, Rng.salt_of("sys_halden"))
	var b: RngStream = Rng.stream(77, 12, Rng.COMBAT, Rng.salt_of("sys_halden"))
	for i in 100:
		t.eq(a.next_u32(), b.next_u32())


func test_streams_are_independent(t: T) -> void:
	var base: Array[int] = _first(Rng.stream(5, 3, Rng.GEN, 0), 4)
	t.ne(base, _first(Rng.stream(5, 4, Rng.GEN, 0), 4), "turn changes the stream")
	t.ne(base, _first(Rng.stream(5, 3, Rng.EVENTS, 0), 4), "stream id changes the stream")
	t.ne(base, _first(Rng.stream(5, 3, Rng.GEN, 1), 4), "salt changes the stream")
	t.ne(base, _first(Rng.stream(6, 3, Rng.GEN, 0), 4), "seed changes the stream")


func test_range_stays_in_bounds_and_covers(t: T) -> void:
	var r: RngStream = Rng.stream(1, 1, Rng.GEN)
	var seen: Dictionary[int, int] = {}
	for i in 6000:
		var x: int = r.range(-2, 3)
		if x < -2 or x > 3:
			t.fail("range(-2, 3) gave %d" % x)
		seen[x] = seen.get(x, 0) + 1
	t.eq(seen.size(), 6, "every value in [-2, 3] appears")
	for k: int in seen.keys():
		t.ok(seen[k] > 800 and seen[k] < 1200, "value %d appeared %d times of 6000" % [k, seen[k]])
	t.eq(r.range(4, 4), 4, "single-value range")


func test_chance_bp_extremes_and_rate(t: T) -> void:
	var r: RngStream = Rng.stream(9, 9, Rng.EVENTS)
	var before: int = r.draws
	t.not_ok(r.chance_bp(0))
	t.ok(r.chance_bp(10000))
	t.eq(r.draws, before, "0% and 100% draw nothing")
	var hits: int = 0
	for i in 10000:
		if r.chance_bp(2500):
			hits += 1
	t.ok(hits > 2300 and hits < 2700, "25%% chance hit %d of 10000" % hits)


func test_weighted(t: T) -> void:
	var r: RngStream = Rng.stream(3, 1, Rng.AI)
	var w: Array[int] = [0, 3, 1, 0]
	var counts: Array[int] = [0, 0, 0, 0]
	for i in 4000:
		counts[r.weighted(w)] += 1
	t.eq(counts[0], 0, "zero weight never chosen")
	t.eq(counts[3], 0, "zero weight never chosen")
	t.ok(counts[1] > 2800 and counts[1] < 3200, "weight 3 of 4 chosen %d of 4000" % counts[1])
	var none: Array[int] = [0, 0]
	t.eq(r.weighted(none), -1, "all-zero weights")


func test_shuffle_is_deterministic_permutation(t: T) -> void:
	var a: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var b: Array = a.duplicate()
	Rng.stream(42, 1, Rng.GEN).shuffle(a)
	Rng.stream(42, 1, Rng.GEN).shuffle(b)
	t.eq(a, b, "same stream, same shuffle")
	var sorted: Array = a.duplicate()
	sorted.sort()
	t.eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8], "shuffle is a permutation")


func _first(r: RngStream, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(r.next_u32())
	return out
