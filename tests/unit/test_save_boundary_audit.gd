extends RefCounted


func _envelope(state: Dictionary, version: int = GameState.SCHEMA_VERSION) -> String:
	var env: Dictionary = CanonicalJson.parse(SaveSerializer.to_text(TinyState.build(), "audit"))
	env["state"] = state
	env["version"] = version
	env["checksum"] = CanonicalJson.sha256_hex(CanonicalJson.stringify(state))
	return CanonicalJson.stringify(env)


func test_save_boundary_audit_empty_and_invalid_state(t: T) -> void:
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(_envelope({}))
	t.not_ok(lr.ok, "a checksummed empty state must not load")
	t.eq(lr.error_key, "save.error.corrupt")
	var state: Dictionary = TinyState.build().to_dict()
	state["empires"]["emp_player"] = "invalid"
	lr = SaveSerializer.from_text(_envelope(state))
	t.not_ok(lr.ok, "invalid entity type must not reach typed reconstruction")
	t.eq(lr.error_key, "save.error.corrupt")


func test_save_boundary_audit_invalid_scalar_and_relationship(t: T) -> void:
	var state: Dictionary = TinyState.build().to_dict()
	state["turn"] = "seven"
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(_envelope(state))
	t.not_ok(lr.ok, "invalid scalar must not silently default")
	state = TinyState.build().to_dict()
	state["empires"]["emp_player"]["stock"]["food"] = -1
	lr = SaveSerializer.from_text(_envelope(state))
	t.not_ok(lr.ok, "invalid reconstructed state must not be offered as playable")
	t.eq(lr.error_key, "save.error.corrupt")


func test_save_boundary_audit_corrupt_slot_remains_listed_and_recoverable(t: T) -> void:
	var saves: Node = (Engine.get_main_loop() as SceneTree).root.get_node("SaveService")
	var old_dir: String = saves.get("dir")
	var dir: String = "user://audit_save_boundary_%d" % Time.get_ticks_usec()
	saves.set("dir", dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join("manual_1.json"), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var listing: Array[Dictionary] = saves.call("list_saves")
	t.eq(listing.size(), 1, "damaged slots must remain visible so they can be deleted")
	var lr: SaveSerializer.LoadResult = saves.call("load_slot", "manual_1")
	t.not_ok(lr.ok)
	t.eq(lr.error_key, "save.error.corrupt")
	saves.call("delete", "manual_1")
	t.eq((saves.call("list_slots") as Array).size(), 0)
	DirAccess.remove_absolute(dir)
	saves.set("dir", old_dir)


func test_save_boundary_audit_failed_replace_preserves_existing_slot(t: T) -> void:
	var saves: Node = (Engine.get_main_loop() as SceneTree).root.get_node("SaveService")
	var old_dir: String = saves.get("dir")
	var dir: String = "user://audit_atomic_%d" % Time.get_ticks_usec()
	saves.set("dir", dir)
	var original: GameState = TinyState.build(12)
	t.eq(saves.call("save", "manual_1", original), OK)
	var before: String = FileAccess.get_file_as_string(dir.path_join("manual_1.json"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("manual_1.json.pending"))
	var newer: GameState = TinyState.build(13)
	t.ne(saves.call("save", "manual_1", newer), OK, "unwritable pending path fails")
	t.eq(FileAccess.get_file_as_string(dir.path_join("manual_1.json")), before, "old slot survives failed write")
	t.eq((saves.call("list_slots") as Array).size(), 1, "pending paths are not offered")
	DirAccess.remove_absolute(dir.path_join("manual_1.json.pending"))
	saves.call("delete", "manual_1")
	DirAccess.remove_absolute(dir)
	saves.set("dir", old_dir)


func test_save_boundary_audit_bad_migration_and_retry(t: T) -> void:
	var state: Dictionary = TinyState.build().to_dict()
	state["schema_version"] = 1
	state["colonies"]["col_0001"]["districts"] = ["invalid"]
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(_envelope(state, 1))
	t.not_ok(lr.ok, "migration must not receive malformed entities")
	t.eq(lr.error_key, "save.error.corrupt")
	var good: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(TinyState.build(), "audit"))
	t.ok(good.ok, "a failed load does not poison the next load")


func test_save_boundary_audit_malformed_presentation_is_nonfatal(t: T) -> void:
	var text: String = SaveSerializer.to_text(TinyState.build(), "audit", "{broken", "[broken")
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(text)
	t.ok(lr.ok, "damaged optional presentation must not reject gameplay")
	t.eq(lr.presentation_status, "invalid")
	t.eq(lr.presentation, "{broken")
	t.eq(lr.presentation_overlay, "[broken")


func test_save_boundary_audit_checkpoint_skips_corrupt_newest(t: T) -> void:
	var saves: Node = (Engine.get_main_loop() as SceneTree).root.get_node("SaveService")
	var old_dir: String = saves.get("dir")
	var dir: String = "user://audit_checkpoint_%d" % Time.get_ticks_usec()
	saves.set("dir", dir)
	var state: GameState = TinyState.build(28)
	state.turn = 5
	t.eq(saves.call("save", "checkpoint_1", state), OK)
	state.turn = 10
	t.eq(saves.call("save", "checkpoint_2", state), OK)
	var path: String = dir.path_join("checkpoint_2.json")
	var env: Dictionary = CanonicalJson.parse(FileAccess.get_file_as_string(path))
	env["checksum"] = "broken"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(CanonicalJson.stringify(env))
	f.close()
	t.eq(saves.call("latest_checkpoint", state.scenario_id, state.game_seed, 11), "checkpoint_1", "select newest valid checkpoint")
	saves.call("delete", "checkpoint_1")
	saves.call("delete", "checkpoint_2")
	DirAccess.remove_absolute(dir)
	saves.set("dir", old_dir)
