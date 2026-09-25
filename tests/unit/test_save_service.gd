extends RefCounted
## Save rings and campaign progress on disk (§5.12, §9.6): 10 auto-saves, 6 checkpoints every 5
## turns, manual saves, deletion, the checkpoint a lost game goes back to, auto-saving only while
## persistence is on, and the campaign file.

var _saves: Node
var _old_dir: String = ""


func _begin() -> String:
	_saves = (Engine.get_main_loop() as SceneTree).root.get_node("SaveService")
	_old_dir = _saves.get("dir")
	var d: String = "user://test_saves_%d" % Time.get_ticks_usec()
	_saves.set("dir", d)
	return d


func _end(d: String) -> void:
	var da: DirAccess = DirAccess.open(d)
	if da != null:
		for f: String in da.get_files():
			DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)
	_saves.set("dir", _old_dir)


func _kinds(list: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in list:
		if s["kind"] == kind:
			out.append(s)
	return out


func test_autosaves_and_checkpoints_keep_their_rings(t: T) -> void:
	var d: String = _begin()
	var st: GameState = TinyState.build(55)
	for turn in range(1, 41):
		st.turn = turn
		t.eq(_saves.call("autosave", st), OK, "turn %d saved" % turn)
	var saves: Array[Dictionary] = _saves.call("list_saves")
	t.eq(_kinds(saves, "auto").size(), 10, "a ring of 10 auto-saves")
	var checkpoints: Array[Dictionary] = _kinds(saves, "checkpoint")
	t.eq(checkpoints.size(), 6, "a ring of 6 checkpoints")
	var turns: Array[int] = []
	for c: Dictionary in checkpoints:
		turns.append(int(c["turn"]))
	turns.sort()
	t.eq(turns, [15, 20, 25, 30, 35, 40] as Array[int], "the six newest checkpoints, every fifth turn")
	var autos: Array[int] = []
	for a: Dictionary in _kinds(saves, "auto"):
		autos.append(int(a["turn"]))
	autos.sort()
	t.eq(autos[0], 31, "the oldest auto-save kept is 10 turns back")
	var slot: String = _saves.call("latest_checkpoint", st.scenario_id, 55, 33)
	t.ne(slot, "", "a checkpoint from before turn 33")
	var lr: SaveSerializer.LoadResult = _saves.call("load_slot", slot)
	t.ok(lr.ok and lr.state.turn == 30, "the newest checkpoint before the loss is turn 30")
	t.eq(_saves.call("latest_checkpoint", st.scenario_id, 56, 33), "", "another game's checkpoints do not count")
	t.eq(_saves.call("latest_checkpoint", st.scenario_id, 55, 15), "", "none from before the ring")
	_end(d)


func test_manual_saves_load_and_delete(t: T) -> void:
	var d: String = _begin()
	var st: GameState = TinyState.build(8)
	var a: String = _saves.call("save_manual", st)
	var b: String = _saves.call("save_manual", st)
	t.eq(a, "manual_1")
	t.eq(b, "manual_2", "a new manual save never overwrites an old one")
	var lr: SaveSerializer.LoadResult = _saves.call("load_slot", a)
	t.ok(lr.ok, "a manual save loads")
	if lr.ok:
		t.eq(lr.state.state_hash(), st.state_hash(), "and restores the same state")
	_saves.call("delete", a)
	var slots: Array[Dictionary] = _saves.call("list_slots")
	t.eq(slots.size(), 1, "deleting removes the save")
	t.eq(SaveService.kind_of("checkpoint_3"), "checkpoint")
	t.eq(SaveService.kind_of("auto_0"), "auto")
	_end(d)


func test_autosave_follows_resolved_turns_only_when_persisting(t: T) -> void:
	var d: String = _begin()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var settings: Node = root.get_node("Settings")
	var game: Node = root.get_node("Game")
	var r: TurnResult = TurnResult.new()
	r.state = TinyState.build(9)
	r.state.turn = 5
	settings.set("persist", false)
	game.emit_signal("turn_resolved", r)
	t.eq((_saves.call("list_slots") as Array).size(), 0, "nothing is written with persistence off")
	settings.set("persist", true)
	game.emit_signal("turn_resolved", r)
	settings.set("persist", false)
	var kinds: Array[String] = []
	for s: Dictionary in _saves.call("list_saves"):
		kinds.append(str(s["kind"]))
	kinds.sort()
	t.eq(kinds, ["auto", "checkpoint"] as Array[String], "turn 5 writes an auto-save and a checkpoint")
	_end(d)


func test_campaign_progress_survives_a_restart(t: T) -> void:
	var path: String = "user://test_campaign_%d.json" % Time.get_ticks_usec()
	var p: CampaignProgress = CampaignProgress.load_file(path)
	t.eq(p.difficulty_id, "normal", "no file: a fresh campaign")
	p.set_difficulty("hard")
	p.record_win("s1_first_light")
	p.pick_legacy("s1_first_light", "seasoned_farmers")
	var q: CampaignProgress = CampaignProgress.load_file(path)
	t.eq(q.difficulty_id, "hard", "the difficulty was saved")
	t.eq(q.legacy_of("s1_first_light"), "seasoned_farmers", "the win and the legacy were saved")
	DirAccess.remove_absolute(path)
