class_name T
extends RefCounted
## Assertion helper handed to every test method: `func test_something(t: T) -> void`.
## Assertions record failures and let the test continue, so one run reports every broken check.

var failures: Array[String] = []
var checks: int = 0


func ok(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		_fail("expected true", message)


func not_ok(condition: bool, message: String = "") -> void:
	checks += 1
	if condition:
		_fail("expected false", message)


func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if not same(actual, expected):
		_fail("expected %s, got %s" % [_show(expected), _show(actual)], message)


func ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	checks += 1
	if same(actual, unexpected):
		_fail("did not expect %s" % _show(unexpected), message)


func near(actual: float, expected: float, epsilon: float, message: String = "") -> void:
	checks += 1
	if absf(actual - expected) > epsilon:
		_fail("expected %s ± %s, got %s" % [expected, epsilon, actual], message)


func empty(list: Array, message: String = "") -> void:
	checks += 1
	if not list.is_empty():
		var shown: Array = list.slice(0, 8)
		_fail("expected empty, got %d item(s): %s" % [list.size(), str(shown)], message)


func fail(message: String) -> void:
	checks += 1
	_fail("failed", message)


## Structural equality that treats typed and untyped containers alike and never mixes int/float.
static func same(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	var arrays: Array[int] = [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY]
	if ta in arrays and tb in arrays:
		var aa: Array = Array(a)
		var bb: Array = Array(b)
		if aa.size() != bb.size():
			return false
		for i in aa.size():
			if not same(aa[i], bb[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k: Variant in da.keys():
			if not db.has(k) or not same(da[k], db[k]):
				return false
		return true
	if ta != tb:
		if (ta == TYPE_STRING and tb == TYPE_STRING_NAME) or (ta == TYPE_STRING_NAME and tb == TYPE_STRING):
			return String(a) == String(b)
		return false
	return a == b


func _fail(what: String, message: String) -> void:
	var where: String = ""
	var stack: Array = get_stack()
	for frame: Dictionary in stack:
		var src: String = str(frame.get("source", ""))
		if not src.ends_with("tests/t.gd"):
			where = "%s:%d" % [src.get_file(), int(frame.get("line", 0))]
			break
	var text: String = what if message.is_empty() else "%s: %s" % [message, what]
	if where != "":
		text = "%s (%s)" % [text, where]
	failures.append(text)


static func _show(v: Variant) -> String:
	var s: String = var_to_str(v) if typeof(v) != TYPE_STRING else "\"%s\"" % v
	if s.length() > 300:
		s = s.substr(0, 300) + "…"
	return s
