extends RefCounted
## Delivered assets (§15.2): every id the manifest marks delivered has its files and they load as
## what the game expects; flipbooks divide into their frames; tracks loop but stings play once;
## store art stays out of the game's pack.


func _delivered(kind: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in Content.db().ids("assets"):
		var rec: Dictionary = Content.db().record("assets", id)
		if DictIO.str_of(rec, "status") == "delivered" and (kind.is_empty() or DictIO.str_of(rec, "kind") == kind):
			out.append(id)
	return out


func test_every_delivered_id_loads(t: T) -> void:
	var ids: Array[String] = _delivered()
	t.ok(ids.size() > 0, "the first batches are in")
	for id: String in ids:
		var rec: Dictionary = Content.db().record("assets", id)
		var kind: String = DictIO.str_of(rec, "kind")
		var files: Array = DictIO.arr_of(rec, "files")
		if files.is_empty():
			files = [DictIO.str_of(rec, "file")]
		t.ok(not str(files[0]).is_empty(), "%s names its file" % id)
		t.ok(DictIO.int_of(rec, "batch") > 0, "%s records its batch" % id)
		for f: Variant in files:
			var p: String = AssetIds.ROOT.path_join(str(f))
			if kind == "store":
				# Store art sits in a folder Godot ignores: the file is kept, the game never loads it.
				t.ok(FileAccess.file_exists(p), "%s: %s exists" % [id, p])
				t.not_ok(ResourceLoader.exists(p), "%s stays out of the game's pack" % id)
			else:
				t.ok(ResourceLoader.exists(p), "%s: %s is imported" % [id, p])
		match kind:
			"sfx", "music":
				t.eq(AssetIds.streams(id).size(), files.size(), "%s: every variant loads" % id)
				t.ok(AssetIds.is_delivered(id), "%s counts as delivered" % id)
			"store":
				t.not_ok(AssetIds.is_delivered(id), "store art is never drawn in the game")
			_:
				t.ok(AssetIds.texture(id) != null, "%s loads as a texture" % id)


func test_flipbooks_divide_into_frames(t: T) -> void:
	for id: String in _delivered("vfx"):
		var rec: Dictionary = Content.db().record("assets", id)
		var grid: Array = DictIO.arr_of(rec, "grid")
		if grid.is_empty():
			continue
		var tex: Texture2D = AssetIds.texture(id)
		t.eq(grid.size(), 2, "%s: columns and rows" % id)
		t.ok(DictIO.int_of(rec, "fps") > 0, "%s has a frame rate" % id)
		t.eq(tex.get_width() % int(grid[0]), 0, "%s: whole frames across" % id)
		t.eq(tex.get_height() % int(grid[1]), 0, "%s: whole frames down" % id)


func test_tracks_loop_but_stings_play_once(t: T) -> void:
	var ids: Array[String] = _delivered("music")
	t.ok(ids.size() > 0)
	for id: String in ids:
		var st: AudioStream = AssetIds.streams(id)[0]
		t.eq(bool(st.get("loop")), not id.begins_with("sting_"), "%s loops: %s" % [id, not id.begins_with("sting_")])
