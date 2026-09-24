class_name StringTable
extends RefCounted
## Reads strings/en.csv (header "key,en"). Quoting follows CSV rules, so bodies may hold commas,
## quotes and line breaks.

const DEFAULT_PATH: String = "res://strings/en.csv"

var entries: Dictionary[String, String] = {}
## Keys in file order.
var keys: Array[String] = []
var errors: Array[String] = []


static func load_csv(path: String = DEFAULT_PATH) -> StringTable:
	var st: StringTable = StringTable.new()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		st.errors.append("cannot open %s" % path)
		return st
	var header: PackedStringArray = f.get_csv_line()
	if header.size() < 2 or header[0] != "key" or header[1] != "en":
		st.errors.append("%s: header must be \"key,en\"" % path)
		return st
	var line_no: int = 1
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		line_no += 1
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() < 2:
			st.errors.append("%s:%d: expected 2 columns, got %d" % [path, line_no, row.size()])
			continue
		var key: String = row[0].strip_edges()
		if key.is_empty():
			st.errors.append("%s:%d: empty key" % [path, line_no])
			continue
		if st.entries.has(key):
			st.errors.append("%s:%d: duplicate key %s" % [path, line_no, key])
			continue
		if row[1].is_empty():
			st.errors.append("%s:%d: empty text for %s" % [path, line_no, key])
		st.entries[key] = row[1]
		st.keys.append(key)
	return st
