extends RefCounted
## The simulation boundary (§9.3): sim/ never touches nodes, the scene tree, input, the UI, or
## engine randomness and hashing (§9.5). Comments and string literals are ignored.

const FORBIDDEN: Array[String] = [
	"\\bNode\\b", "\\bNode2D\\b", "\\bNode3D\\b", "\\bControl\\b", "\\bSceneTree\\b",
	"\\bget_tree\\b", "\\bInput\\b", "\\bInputEvent\\w*\\b", "\\bViewport\\b", "\\bDisplayServer\\b",
	"\\bCanvasItem\\b", "\\bTween\\b", "\\bPackedScene\\b", "\\bTokens\\b", "\\bLayout\\b",
	"\\bSettings\\b", "\\bStrings\\b", "\\bGame\\b", "\\bSaveService\\b",
	"\\brandi\\b", "\\brandf\\b", "\\brandf_range\\b", "\\brandi_range\\b", "\\brandomize\\b",
	"\\bRandomNumberGenerator\\b", "(?<![\\w.])hash\\(", "\\bTime\\.", "\\bOS\\.",
]


func test_sim_has_no_forbidden_identifiers(t: T) -> void:
	var files: Array[String] = []
	_collect("res://sim", files)
	t.ok(files.size() > 10, "found the sim scripts (%d)" % files.size())
	var patterns: Array[RegEx] = []
	for p: String in FORBIDDEN:
		patterns.append(RegEx.create_from_string(p))
	var ui_path: RegEx = RegEx.create_from_string("res://(ui|app)/")
	for f: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(f).split("\n")
		for i in lines.size():
			var raw: String = lines[i]
			if ui_path.search(raw) != null:
				t.fail("%s:%d references ui/ or app/: %s" % [f, i + 1, raw.strip_edges()])
			var code: String = _strip(raw)
			for j in patterns.size():
				if patterns[j].search(code) != null:
					t.fail("%s:%d uses forbidden %s: %s" % [f.trim_prefix("res://"), i + 1, FORBIDDEN[j], raw.strip_edges()])


func test_scanner_catches_violations(t: T) -> void:
	var re: RegEx = RegEx.create_from_string("\\bNode\\b")
	t.ok(re.search(_strip("var n: Node = null")) != null)
	t.ok(re.search(_strip("# a Node in a comment")) == null, "comments are ignored")
	t.ok(re.search(_strip("var s: String = \"Node\"")) == null, "strings are ignored")
	var h: RegEx = RegEx.create_from_string("(?<![\\w.])hash\\(")
	t.ok(h.search(_strip("var x: int = hash(key)")) != null)
	t.ok(h.search(_strip("var x: String = state.state_hash()")) == null)


## Removes string literals and comments from one line of GDScript.
static func _strip(line: String) -> String:
	var out: String = ""
	var in_str: bool = false
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
			i += 1
			continue
		if c == "#":
			break
		if c == "\"" or c == "'":
			in_str = true
			quote = c
			out += " "
			i += 1
			continue
		out += c
		i += 1
	return out


static func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
