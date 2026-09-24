extends RefCounted
## Canonical JSON: sorted keys, no whitespace, integers only, stable escaping.


func test_sorted_keys_and_no_whitespace(t: T) -> void:
	var text: String = CanonicalJson.stringify({"b": 1, "a": [3, 2, {"z": true, "c": null}], "A": "x"})
	t.eq(text, "{\"A\":\"x\",\"a\":[3,2,{\"c\":null,\"z\":true}],\"b\":1}")


func test_floats_are_rejected(t: T) -> void:
	var errors: Array[String] = []
	var text: String = CanonicalJson.stringify({"stock": {"food": 1.5}}, errors)
	t.eq(text, "", "no output when a float is present")
	t.eq(errors.size(), 1)
	t.ok(errors[0].contains("$.stock.food"), "error names the path: %s" % str(errors))


func test_whole_floats_are_rejected_too(t: T) -> void:
	var errors: Array[String] = []
	CanonicalJson.stringify([2.0], errors)
	t.eq(errors.size(), 1, "2.0 is a float in state, even if it is whole")


func test_escaping(t: T) -> void:
	t.eq(CanonicalJson.stringify("a\"b\\c"), "\"a\\\"b\\\\c\"")
	t.eq(CanonicalJson.stringify("line\nnext\ttab"), "\"line\\nnext\\ttab\"")
	t.eq(CanonicalJson.stringify(String.chr(1)), "\"\\u0001\"")
	t.eq(CanonicalJson.stringify("Ærø ★"), "\"Ærø ★\"", "non-ASCII stays raw UTF-8")


func test_parse_restores_ints(t: T) -> void:
	var errors: Array[String] = []
	var v: Variant = CanonicalJson.parse("{\"a\": 5, \"b\": [1, 2.0], \"c\": {\"d\": -7}}", errors)
	t.empty(errors)
	t.eq(typeof(v["a"]), TYPE_INT)
	t.eq(typeof(v["b"][1]), TYPE_INT)
	t.eq(v["c"]["d"], -7)


func test_parse_reports_fractions(t: T) -> void:
	var errors: Array[String] = []
	CanonicalJson.parse("{\"a\": 1.25}", errors)
	t.eq(errors.size(), 1)


func test_round_trip_is_byte_identical(t: T) -> void:
	var src: Dictionary = {"k": [1, {"x": "y"}], "n": -12, "s": "é\n"}
	var text: String = CanonicalJson.stringify(src)
	var back: Variant = CanonicalJson.parse(text)
	t.eq(CanonicalJson.stringify(back), text)


func test_sha256(t: T) -> void:
	t.eq(CanonicalJson.sha256_hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
