class_name PresentationEnvelope
extends RefCounted
## Opaque transport outside the gameplay checksum. Future JSON remains a STRING
## so its numeric/extension types cannot weaken the integer-only simulation boundary.
const FORMAT: String = "starfire-hearth-appearance"
const VERSION: int = 2

static func pack(data: Dictionary, version: int = 1) -> String:
	var payload: String = CanonicalJson.stringify(data)
	if payload.is_empty(): return ""
	return CanonicalJson.stringify({"format": FORMAT, "version": version,
		"payload": payload, "checksum": CanonicalJson.sha256_hex(payload)})

static func repack(data: Dictionary, original: String, version: int = 1) -> String:
	var current: Dictionary = CanonicalJson.parse(pack(data,version))
	var previous: Variant = JSON.parse_string(original)
	if previous is Dictionary:
		for key: String in previous:
			if not current.has(key): current[key] = previous[key]
	# Unknown wrapper extensions may contain future fractional values. They stay
	# inside this opaque string and never enter canonical simulation JSON.
	return JSON.stringify(current, "", true)

static func inspect(raw: String) -> Dictionary:
	if raw.is_empty(): return {"status": "missing", "data": {}}
	var wrapper: Variant = JSON.parse_string(raw)
	if not wrapper is Dictionary or wrapper.get("format") != FORMAT:
		return {"status": "invalid", "data": {}}
	var payload: Variant = wrapper.get("payload")
	var version: Variant = wrapper.get("version")
	if not payload is String or not version is float and not version is int:
		return {"status": "invalid", "data": {}}
	if float(version) != floorf(float(version)) or version < 0 or version > 2147483647:
		return {"status": "invalid", "data": {}}
	if wrapper.get("checksum") != CanonicalJson.sha256_hex(payload):
		return {"status": "invalid", "data": {}}
	if int(version) > VERSION:
		return {"status": "future", "data": {}, "compatibility": wrapper.get("compatibility", "")}
	var errors: Array[String] = []
	var data: Variant = CanonicalJson.parse(payload, errors)
	if not errors.is_empty() or not data is Dictionary:
		return {"status": "invalid", "data": {}}
	return {"status": "supported", "version": int(version), "data": data}
