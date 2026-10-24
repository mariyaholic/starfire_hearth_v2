class_name PresentationEnvelope
extends RefCounted
## Opaque transport outside the gameplay checksum. Future JSON remains a STRING
## so its numeric/extension types cannot weaken the integer-only simulation boundary.
const FORMAT: String = "starfire-hearth-appearance"
const VERSION: int = 2
## M1.2 road/orbit data is transported as optional wrapper components.  The
## appearance payload and its exact catalog dictionary remain M1.1-shaped.
const COMPONENT_FORMAT: String = "starfire-hearth-presentation-component"
const COMPONENT_VERSION: int = 1
const COMPONENT_NAMES: Array[String] = ["road", "orbit"]

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


## Repack a supported component while preserving unknown component-wrapper
## extensions. A future component must stay opaque and is never downgraded by
## this helper.
static func repack_component(data: Dictionary, original: String, version: int = -1) -> String:
	var inspected: Dictionary = inspect_component(original)
	if inspected.get("status") != "supported": return ""
	var kind: String = str(inspected.get("component", ""))
	var target_version: int = int(inspected.get("version", COMPONENT_VERSION)) if version < 0 else version
	var packed: String = pack_component(kind, data, target_version)
	if packed.is_empty(): return ""
	var current: Dictionary = JSON.parse_string(packed)
	var previous: Variant = JSON.parse_string(original)
	if previous is Dictionary:
		for key: String in previous:
			if not current.has(key): current[key] = previous[key]
	return JSON.stringify(current, "", true)


## A component has its own version/checksum and a canonical integer payload.
## It stays inside the outer appearance string so no gameplay schema changes.
static func pack_component(kind: String, data: Dictionary, version: int = COMPONENT_VERSION, compatibility: String = "") -> String:
	if kind not in COMPONENT_NAMES or version < 0 or version > 2147483647: return ""
	var payload: String = CanonicalJson.stringify(data)
	if payload.is_empty(): return ""
	var wrapper: Dictionary = {"component":kind, "format":COMPONENT_FORMAT,
		"version":version, "payload":payload, "checksum":CanonicalJson.sha256_hex(payload)}
	if not compatibility.is_empty(): wrapper["compatibility"] = compatibility
	return CanonicalJson.stringify(wrapper)


static func inspect_component(raw: String, expected_kind: String = "") -> Dictionary:
	if raw.is_empty(): return {"status":"missing", "data":{}, "raw":raw}
	var wrapper: Variant = JSON.parse_string(raw)
	if not wrapper is Dictionary or wrapper.get("format") != COMPONENT_FORMAT:
		return {"status":"invalid", "data":{}, "raw":raw}
	var kind: Variant = wrapper.get("component")
	var payload: Variant = wrapper.get("payload")
	var version: Variant = wrapper.get("version")
	if not kind is String or kind not in COMPONENT_NAMES or (not expected_kind.is_empty() and kind != expected_kind):
		return {"status":"invalid", "data":{}, "raw":raw}
	if not payload is String or not (version is float or version is int):
		return {"status":"invalid", "data":{}, "raw":raw}
	if float(version) != floorf(float(version)) or version < 0 or version > 2147483647:
		return {"status":"invalid", "data":{}, "raw":raw}
	if wrapper.get("checksum") != CanonicalJson.sha256_hex(payload):
		return {"status":"invalid", "data":{}, "raw":raw}
	if int(version) > COMPONENT_VERSION:
		return {"status":"future", "component":kind, "version":int(version), "data":{},
			"compatibility":wrapper.get("compatibility", ""), "raw":raw}
	var errors: Array[String] = []
	var data: Variant = CanonicalJson.parse(payload, errors)
	if not errors.is_empty() or not data is Dictionary:
		return {"status":"invalid", "data":{}, "raw":raw}
	return {"status":"supported", "component":kind, "version":int(version), "data":data,
		"raw":raw}


## Return string component entries without interpreting unknown names or values.
static func component_raws(raw: String) -> Dictionary:
	var out: Dictionary = {}
	if raw.is_empty(): return out
	var wrapper: Variant = JSON.parse_string(raw)
	if not wrapper is Dictionary: return out
	var components: Variant = wrapper.get("components", {})
	if not components is Dictionary: return out
	for kind: String in components:
		if components[kind] is String: out[kind] = components[kind]
	return out


## Merge component strings into a wrapper while retaining unknown wrapper keys.
static func with_components(raw: String, components: Dictionary) -> String:
	var wrapper: Variant = JSON.parse_string(raw)
	if not wrapper is Dictionary: return raw
	var merged: Dictionary = {}
	var previous: Variant = wrapper.get("components", {})
	if previous is Dictionary: merged = previous.duplicate(true)
	for kind: String in components:
		if components[kind] is String: merged[kind] = components[kind]
	if not merged.is_empty(): wrapper["components"] = merged
	return JSON.stringify(wrapper, "", true)

static func inspect(raw: String) -> Dictionary:
	if raw.is_empty(): return {"status": "missing", "data": {}, "components": {}}
	var wrapper: Variant = JSON.parse_string(raw)
	if not wrapper is Dictionary or wrapper.get("format") != FORMAT:
		return {"status": "invalid", "data": {}, "components": component_raws(raw)}
	var payload: Variant = wrapper.get("payload")
	var version: Variant = wrapper.get("version")
	if not payload is String or not version is float and not version is int:
		return {"status": "invalid", "data": {}, "components": component_raws(raw)}
	if float(version) != floorf(float(version)) or version < 0 or version > 2147483647:
		return {"status": "invalid", "data": {}, "components": component_raws(raw)}
	if wrapper.get("checksum") != CanonicalJson.sha256_hex(payload):
		return {"status": "invalid", "data": {}, "components": component_raws(raw)}
	if int(version) > VERSION:
		return {"status": "future", "data": {}, "compatibility": wrapper.get("compatibility", ""), "components": component_raws(raw)}
	var errors: Array[String] = []
	var data: Variant = CanonicalJson.parse(payload, errors)
	if not errors.is_empty() or not data is Dictionary:
		return {"status": "invalid", "data": {}, "components": component_raws(raw)}
	return {"status": "supported", "version": int(version), "data": data, "components": component_raws(raw)}
