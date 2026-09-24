extends RefCounted
## RNG golden vectors (§9.5). The expected numbers in rng_vectors.json were produced by an
## independent arbitrary-precision implementation, not by this code.

const VECTORS_PATH: String = "res://tests/golden/rng_vectors.json"


func _vectors() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(VECTORS_PATH)
	return CanonicalJson.parse(text)


func test_raw_state_matches_published_xoshiro128ss_vector(t: T) -> void:
	var v: Dictionary = _vectors()
	var r: RngStream = RngStream.new(1, 2, 3, 4)
	var got: Array[int] = []
	for i in 10:
		got.append(r.next_u32())
	t.eq(got, v["raw_state_1_2_3_4"])
	t.eq(got[0], 11520, "first output of xoshiro128** from state {1,2,3,4}")


func test_stream_vectors_first_ten_outputs(t: T) -> void:
	var v: Dictionary = _vectors()
	for c: Dictionary in v["cases"]:
		var salt: int = c["salt"]
		if str(c["salt_text"]) != "":
			t.eq(Rng.salt_of(c["salt_text"]), salt, "salt for %s" % c["name"])
		var r: RngStream = Rng.stream(c["seed"], c["turn"], c["stream"], salt)
		var got: Array[int] = []
		for i in 10:
			got.append(r.next_u32())
		t.eq(got, c["first_10_u32"], c["name"])


func test_stream_vectors_range(t: T) -> void:
	var v: Dictionary = _vectors()
	for c: Dictionary in v["cases"]:
		var r: RngStream = Rng.stream(c["seed"], c["turn"], c["stream"], c["salt"])
		var got: Array[int] = []
		for i in 10:
			got.append(r.range(1, 6))
		t.eq(got, c["range_1_6_x10"], c["name"])


func test_helpers_match_reference(t: T) -> void:
	var v: Dictionary = _vectors()
	var salts: Dictionary = v["salt_of"]
	for text: String in salts.keys():
		t.eq(Rng.salt_of(text), salts[text], "salt_of('%s')" % text)
	var mixes: Dictionary = v["fmix32"]
	for k: String in mixes.keys():
		t.eq(Rng.fmix32(k.to_int()), mixes[k], "fmix32(%s)" % k)
