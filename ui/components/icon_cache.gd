class_name IconCache
extends RefCounted
## Rasterises SVG icons (assets/icons, authored on a 24x24 grid in white) at the exact physical
## pixel size they are drawn at, so they stay crisp at every UI scale. Tint with modulate or the
## draw colour. Files are exported as-is (their .import files say "keep").

const DIR: String = "res://assets/icons"

static var _textures: Dictionary[String, Texture2D] = {}
static var _sources: Dictionary[String, String] = {}


static func path_of(icon_id: String, outline: bool = false) -> String:
	return "%s/%s%s.svg" % [DIR, icon_id, "_outline" if outline else ""]


static func exists(icon_id: String) -> bool:
	return FileAccess.file_exists(path_of(icon_id))


## Texture of `icon_id` rasterised at `px` physical pixels square. Null if the icon is missing.
static func texture(icon_id: String, px: int, outline: bool = false) -> Texture2D:
	px = clampi(px, 8, 512)
	var key: String = "%s|%s|%d" % [icon_id, outline, px]
	if _textures.has(key):
		return _textures[key]
	var path: String = path_of(icon_id, outline)
	if not _sources.has(path):
		_sources[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var svg: String = _sources[path]
	if svg.is_empty():
		push_warning("IconCache: no icon \"%s\"" % icon_id)
		return null
	var img: Image = Image.new()
	if img.load_svg_from_string(svg, px / 24.0) != OK:
		push_warning("IconCache: cannot rasterise \"%s\"" % icon_id)
		return null
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## Every icon id (filled variants), sorted.
static func all_ids() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".svg") and not f.ends_with("_outline.svg"):
			out.append(f.get_basename())
	out.sort()
	return out
