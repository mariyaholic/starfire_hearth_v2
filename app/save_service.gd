extends Node
## Save files (§5.12, §9.6): an auto-save after every turn in a ring of 10, a checkpoint every 5
## turns in a ring of 6, and manual saves; each has a small PNG thumbnail beside it when a
## renderer is running. The simulation never touches files: the app saves once a turn has
## resolved. Nothing is written while Settings.persist is off (tests, the screenshot tour), except
## through the explicit calls below.

const DIR: String = "user://saves"
const EXT: String = ".json"
const AUTO_RING: int = 10
const CHECKPOINT_RING: int = 6
const CHECKPOINT_EVERY: int = 5
const THUMB_SIZE: Vector2i = Vector2i(320, 180)
const KIND_AUTO: String = "auto"
const KIND_CHECKPOINT: String = "checkpoint"
const KIND_MANUAL: String = "manual"

## Where saves go; tests point it at a scratch folder.
var dir: String = DIR


func _ready() -> void:
	Game.turn_resolved.connect(_on_turn_resolved)


func save(slot: String, state: GameState) -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	var text: String = SaveSerializer.to_text(state, Game.game_version())
	if text.is_empty():
		return ERR_INVALID_DATA
	var f: FileAccess = FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	_write_thumbnail(slot)
	return OK


## The auto-save for a turn, plus a checkpoint on every fifth turn.
func autosave(state: GameState) -> Error:
	var err: Error = save("%s_%d" % [KIND_AUTO, state.turn % AUTO_RING], state)
	if err == OK and state.turn % CHECKPOINT_EVERY == 0:
		err = save("%s_%d" % [KIND_CHECKPOINT, (state.turn / CHECKPOINT_EVERY) % CHECKPOINT_RING], state)
	return err


## A new manual save; returns its slot, or "" when writing failed.
func save_manual(state: GameState) -> String:
	var n: int = 1
	while FileAccess.file_exists(_path("%s_%d" % [KIND_MANUAL, n])):
		n += 1
	var slot: String = "%s_%d" % [KIND_MANUAL, n]
	return slot if save(slot, state) == OK else ""


func load_slot(slot: String) -> SaveSerializer.LoadResult:
	if not FileAccess.file_exists(_path(slot)):
		var lr: SaveSerializer.LoadResult = SaveSerializer.LoadResult.new()
		lr.error_key = "save.error.corrupt"
		lr.error_detail = "no save in slot %s" % slot
		return lr
	return SaveSerializer.from_text(FileAccess.get_file_as_string(_path(slot)))


func delete(slot: String) -> void:
	for p: String in [_path(slot), thumbnail_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## [{slot, modified}] newest first.
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(EXT):
			out.append({"slot": f.trim_suffix(EXT), "modified": FileAccess.get_modified_time(dir.path_join(f))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]) or (int(a["modified"]) == int(b["modified"]) and str(a["slot"]) < str(b["slot"])))
	return out


## Every save with what a list needs, newest first: slot, kind, modified, scenario_id, turn,
## seed and thumbnail (a path, or "" when there is none). Read from the envelope, unchecked.
func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in list_slots():
		var slot: String = s["slot"]
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var env: Dictionary = v
		var thumb: String = thumbnail_path(slot)
		out.append({
			"slot": slot,
			"kind": kind_of(slot),
			"modified": s["modified"],
			"scenario_id": DictIO.str_of(env, "scenario_id"),
			"turn": DictIO.int_of(env, "turn"),
			"seed": DictIO.int_of(env, "seed"),
			"thumbnail": thumb if FileAccess.file_exists(thumb) else "",
		})
	return out


## The newest checkpoint of a game (its scenario and seed) from before a turn, or "".
func latest_checkpoint(scenario_id: String, game_seed: int, before_turn: int) -> String:
	var best: String = ""
	var best_turn: int = -1
	for s: Dictionary in list_saves():
		if s["kind"] != KIND_CHECKPOINT or s["scenario_id"] != scenario_id or int(s["seed"]) != game_seed:
			continue
		var turn: int = s["turn"]
		if turn < before_turn and turn > best_turn:
			best = s["slot"]
			best_turn = turn
	return best


static func kind_of(slot: String) -> String:
	for k: String in [KIND_AUTO, KIND_CHECKPOINT, KIND_MANUAL]:
		if slot.begins_with(k + "_"):
			return k
	return KIND_MANUAL


func thumbnail_path(slot: String) -> String:
	return dir.path_join(slot.validate_filename() + ".png")


func _on_turn_resolved(r: TurnResult) -> void:
	if Settings.persist and r.state != null:
		autosave(r.state)


func _write_thumbnail(slot: String) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var tex: ViewportTexture = get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return
	# As wide as THUMB_SIZE, keeping the window's shape (phones are wider than 16:9).
	img.resize(THUMB_SIZE.x, maxi(1, roundi(THUMB_SIZE.x * img.get_height() / float(img.get_width()))), Image.INTERPOLATE_BILINEAR)
	img.save_png(thumbnail_path(slot))


func _path(slot: String) -> String:
	return dir.path_join(slot.validate_filename() + EXT)
