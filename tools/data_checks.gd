class_name DataChecks
extends RefCounted
## Everything tools/validate_data.gd checks, as a function the test suite can call too.
## Adds presentation-side checks to DataValidator: icon files exist, colour tokens exist, and no
## string key is orphaned (keys may be used by data or as literals in code).

const CODE_ROOTS: Array[String] = ["res://sim", "res://ui", "res://app", "res://tools"]
const ICON_DIR: String = "res://assets/icons"


class Report:
	extends RefCounted
	var errors: Array[String] = []
	var skips: Array[String] = []
	var tables: int = 0
	var records: int = 0
	var strings: int = 0


static func run(data_root: String = ContentDb.DEFAULT_ROOT, strings_path: String = StringTable.DEFAULT_PATH) -> Report:
	var rep: Report = Report.new()
	var db: ContentDb = ContentDb.load_from(data_root)
	var st: StringTable = StringTable.load_csv(strings_path)
	var v: DataValidator = DataValidator.run(db, st)
	for i: Dictionary in v.errors():
		rep.errors.append("%s: %s" % [i["where"], i["message"]])
	for i: Dictionary in v.skips():
		rep.skips.append("%s: %s" % [i["where"], i["message"]])
	for icon: String in DictIO.sorted_keys(v.used_icons):
		if not FileAccess.file_exists("%s/%s.svg" % [ICON_DIR, icon]):
			rep.errors.append("%s: icon \"%s\" has no file assets/icons/%s.svg" % [v.used_icons[icon], icon, icon])
	for token: String in DictIO.sorted_keys(v.used_tokens):
		if not Tokens.has(token):
			rep.errors.append("%s: \"%s\" is not a colour token in ui/theme/tokens.gd" % [v.used_tokens[token], token])
	for folder: String in ["scenarios", "events", "codex"]:
		if not DirAccess.dir_exists_absolute(data_root.path_join(folder)):
			rep.errors.append("data/%s: folder is missing (it is part of the layout in section 9.2)" % folder)
	var used_in_code: Dictionary[String, bool] = code_string_keys()
	for id: String in icon_ids():
		used_in_code["icon." + id] = true
		if not st.entries.has("icon." + id):
			rep.errors.append("strings/en.csv: icon \"%s\" has no display name (key icon.%s)" % [id, id])
	for k: String in v.orphaned_keys(used_in_code):
		rep.errors.append("strings/en.csv: key \"%s\" is not used by any data file or code" % k)
	rep.tables = DataSchema.TABLES.size()
	for t: String in db.tables.keys():
		rep.records += db.table(t).size()
	rep.strings = st.keys.size()
	return rep


## Every icon id (filled variants) in assets/icons.
static func icon_ids() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(ICON_DIR)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".svg") and not f.ends_with("_outline.svg"):
			out.append(f.get_basename())
	out.sort()
	return out


## Every dotted lower-case string literal in code, e.g. "ui.topbar.food". A superset of the keys
## code really uses, which only makes the orphan check more lenient, never wrong.
static func code_string_keys(roots: Array[String] = CODE_ROOTS) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	var re: RegEx = RegEx.create_from_string("\"([a-z0-9_]+(?:\\.[a-z0-9_]+)+)\"")
	var files: Array[String] = []
	for r: String in roots:
		_collect(r, files)
	for f: String in files:
		var text: String = FileAccess.get_file_as_string(f)
		for m: RegExMatch in re.search_all(text):
			out[m.get_string(1)] = true
	return out


static func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f: String in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
