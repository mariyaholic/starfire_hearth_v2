class_name CanonicalJson
extends RefCounted
## Deterministic JSON for hashing and saving: object keys sorted by code point, no whitespace,
## integers only. A float anywhere is an error, which is how float leaks into simulation state
## are caught (the state hash cannot be computed).

static var _needs_escape: RegEx = RegEx.create_from_string("[\\x00-\\x1f\"\\\\]")


## Returns the canonical text, or "" with `errors` filled when the value is not representable.
static func stringify(value: Variant, errors: Array[String] = []) -> String:
	var out: PackedStringArray = PackedStringArray()
	_write(value, out, "$", errors)
	if not errors.is_empty():
		return ""
	return "".join(out)


static func sha256_hex(text: String) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


## Parses JSON text and converts every integral number back to int (Godot parses all numbers as
## floats). Non-integral numbers are reported in `errors` and left as floats.
static func parse(text: String, errors: Array[String] = []) -> Variant:
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		errors.append("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	return ints(json.data, "$", errors)


## Recursively converts integral floats to ints.
static func ints(value: Variant, path: String = "$", errors: Array[String] = []) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if f == floorf(f) and absf(f) <= 9007199254740992.0:
				return int(f)
			errors.append("non-integer number %s at %s" % [str(f), path])
			return f
		TYPE_ARRAY:
			var arr: Array = value
			var out: Array = []
			for i in arr.size():
				out.append(ints(arr[i], "%s[%d]" % [path, i], errors))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = value
			var out_d: Dictionary = {}
			for k: Variant in d.keys():
				out_d[k] = ints(d[k], "%s.%s" % [path, str(k)], errors)
			return out_d
	return value


static func _write(v: Variant, out: PackedStringArray, path: String, errors: Array[String]) -> void:
	match typeof(v):
		TYPE_NIL:
			out.append("null")
		TYPE_BOOL:
			out.append("true" if v else "false")
		TYPE_INT:
			out.append(str(v))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(_quote(String(v)))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			out.append("[")
			var i: int = 0
			for item: Variant in v:
				if i > 0:
					out.append(",")
				_write(item, out, "%s[%d]" % [path, i], errors)
				i += 1
			out.append("]")
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			for k: Variant in keys:
				if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
					errors.append("non-string key %s at %s" % [str(k), path])
					return
			var skeys: Array[String] = []
			for k: Variant in keys:
				skeys.append(String(k))
			skeys.sort()
			out.append("{")
			var first: bool = true
			for k: String in skeys:
				if not first:
					out.append(",")
				first = false
				out.append(_quote(k))
				out.append(":")
				_write(d[k], out, "%s.%s" % [path, k], errors)
			out.append("}")
		TYPE_FLOAT:
			errors.append("float %s at %s (simulation state must be integers)" % [str(v), path])
		_:
			errors.append("unsupported type %s at %s" % [type_string(typeof(v)), path])


static func _quote(s: String) -> String:
	if _needs_escape.search(s) == null:
		return "\"" + s + "\""
	var parts: PackedStringArray = PackedStringArray()
	parts.append("\"")
	for i in s.length():
		var c: int = s.unicode_at(i)
		match c:
			0x22:
				parts.append("\\\"")
			0x5C:
				parts.append("\\\\")
			0x08:
				parts.append("\\b")
			0x0C:
				parts.append("\\f")
			0x0A:
				parts.append("\\n")
			0x0D:
				parts.append("\\r")
			0x09:
				parts.append("\\t")
			_:
				if c < 0x20:
					parts.append("\\u%04x" % c)
				else:
					parts.append(String.chr(c))
	parts.append("\"")
	return "".join(parts)
