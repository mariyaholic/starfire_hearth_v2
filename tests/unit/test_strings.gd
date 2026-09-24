extends RefCounted
## The string table (§9.7): loads cleanly, keys are namespaced, placeholders are well formed.


func test_table_loads_without_errors(t: T) -> void:
	var st: StringTable = StringTable.load_csv()
	t.empty(st.errors)
	t.ok(st.keys.size() > 50, "keys: %d" % st.keys.size())


func test_keys_are_namespaced(t: T) -> void:
	var re: RegEx = RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)+$")
	for k: String in StringTable.load_csv().keys:
		if re.search(k) == null:
			t.fail("key \"%s\" is not namespaced like ui.topbar.food" % k)


func test_placeholders_are_well_formed(t: T) -> void:
	var ok_re: RegEx = RegEx.create_from_string("\\{[a-z_][a-z0-9_]*\\}")
	var st: StringTable = StringTable.load_csv()
	for k: String in st.keys:
		var text: String = ok_re.sub(st.entries[k], "", true)
		if text.contains("{") or text.contains("}"):
			t.fail("%s has a malformed placeholder: %s" % [k, st.entries[k]])


func test_no_raw_ids_or_typographic_slips_in_text(t: T) -> void:
	var raw_id: RegEx = RegEx.create_from_string("\\b[a-z0-9]+(_[a-z0-9]+)+\\b")
	var ok_re: RegEx = RegEx.create_from_string("\\{[a-z_][a-z0-9_]*\\}")
	var st: StringTable = StringTable.load_csv()
	for k: String in st.keys:
		var text: String = ok_re.sub(st.entries[k], "", true)
		var m: RegExMatch = raw_id.search(text)
		if m != null:
			t.fail("%s shows something that looks like an internal id: %s" % [k, m.get_string()])
		var raw: String = st.entries[k]
		if raw.contains("  "):
			t.fail("%s has a double space" % k)
		if raw != raw.strip_edges():
			t.fail("%s has leading or trailing spaces" % k)


func test_malformed_csv_is_reported(t: T) -> void:
	var path: String = "user://test_bad_strings.csv"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("key,en\nui.a,One\nui.a,Again\nui.b,\n")
	f.close()
	var st: StringTable = StringTable.load_csv(path)
	t.eq(st.errors.size(), 2, str(st.errors))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
