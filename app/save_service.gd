extends Node
## Save files in user://saves (§9.6). M0 has manual slots; the auto-save ring of 10 and the
## checkpoint ring of 6 arrive with the turn loop in M1.

const DIR: String = "user://saves"
const EXT: String = ".json"


func save(slot: String, state: GameState) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var text: String = SaveSerializer.to_text(state, Game.game_version())
	if text.is_empty():
		return ERR_INVALID_DATA
	var f: FileAccess = FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	return OK


func load_slot(slot: String) -> SaveSerializer.LoadResult:
	if not FileAccess.file_exists(_path(slot)):
		var lr: SaveSerializer.LoadResult = SaveSerializer.LoadResult.new()
		lr.error_key = "save.error.corrupt"
		lr.error_detail = "no save in slot %s" % slot
		return lr
	return SaveSerializer.from_text(FileAccess.get_file_as_string(_path(slot)))


## [{slot, modified}] newest first.
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(EXT):
			out.append({"slot": f.trim_suffix(EXT), "modified": FileAccess.get_modified_time(DIR.path_join(f))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]))
	return out


func _path(slot: String) -> String:
	return DIR.path_join(slot.validate_filename() + EXT)
