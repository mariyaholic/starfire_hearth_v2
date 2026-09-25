class_name AssetIds
extends RefCounted
## Resolves a §15 asset id (data/asset_manifest.json) to its delivered file, or null so the caller
## draws its code placeholder. Outsourcing is on hold (DESIGN_LOG 50), so today every id resolves
## to its placeholder; the intake tool (§15.2) flips an entry to "delivered" with its file.

const ROOT: String = "res://assets/delivered"

static var _cache: Dictionary[String, Texture2D] = {}


## The delivered file path for an id, or "" when it is still a placeholder.
static func path(asset_id: String) -> String:
	var rec: Dictionary = Content.db().record("assets", asset_id)
	if DictIO.str_of(rec, "status") != "delivered":
		return ""
	var file: String = DictIO.str_of(rec, "file")
	if file.is_empty():
		return ""
	var p: String = ROOT.path_join(file)
	return p if ResourceLoader.exists(p) else ""


## The delivered image for an id, or null.
static func texture(asset_id: String) -> Texture2D:
	if _cache.has(asset_id):
		return _cache[asset_id]
	var p: String = path(asset_id)
	var tex: Texture2D = null
	if not p.is_empty():
		tex = load(p) as Texture2D
	_cache[asset_id] = tex
	return tex


static func is_delivered(asset_id: String) -> bool:
	return not path(asset_id).is_empty()


## The delivered sound or music for an id: one stream, or one per variant when the intake tool
## recorded "files" (§15.4 ×3 sounds). Empty while the id is a placeholder.
static func streams(asset_id: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	var rec: Dictionary = Content.db().record("assets", asset_id)
	if DictIO.str_of(rec, "status") != "delivered":
		return out
	var files: Array = DictIO.arr_of(rec, "files")
	if files.is_empty() and not DictIO.str_of(rec, "file").is_empty():
		files = [DictIO.str_of(rec, "file")]
	for f: Variant in files:
		var p: String = ROOT.path_join(str(f))
		if ResourceLoader.exists(p):
			var st: AudioStream = load(p) as AudioStream
			if st != null:
				out.append(st)
	return out
