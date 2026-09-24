extends RefCounted
## Command validation (with reasons), application, registry and the undoable queue.


func test_rename_validates_with_reasons(t: T) -> void:
	var s: GameState = TinyState.build()
	t.eq(RenameColonyCommand.create("emp_player", "col_0001", "New Hearth").validate(s).ok, true)
	t.eq(RenameColonyCommand.create("emp_player", "col_9999", "X").validate(s).reason_key, "error.colony.not_found")
	t.eq(RenameColonyCommand.create("emp_meridian", "col_0001", "X").validate(s).reason_key, "error.colony.not_owned")
	t.eq(RenameColonyCommand.create("emp_ghost", "col_0001", "X").validate(s).reason_key, "error.empire.not_found")
	var long: Result = RenameColonyCommand.create("emp_player", "col_0001", "x".repeat(25)).validate(s)
	t.eq(long.reason_key, "error.name.too_long")
	t.eq(long.args, {"max": 24})
	t.eq(RenameColonyCommand.create("emp_player", "col_0001", "a\u0007b").validate(s).reason_key, "error.name.invalid_chars")


func test_rename_applies_trimmed_name(t: T) -> void:
	var s: GameState = TinyState.build()
	RenameColonyCommand.create("emp_player", "col_0001", "  Hearthside ").apply(s)
	t.eq(s.colonies["col_0001"].name, "Hearthside")


func test_job_priority_must_be_a_permutation(t: T) -> void:
	var s: GameState = TinyState.build()
	var good: Array[String] = ["research", "food", "energy", "minerals", "alloys", "clerks"]
	var dup: Array[String] = ["food", "food", "energy", "minerals", "alloys", "clerks"]
	var short: Array[String] = ["food"]
	t.ok(SetJobPriorityCommand.create("emp_player", "col_0001", good).validate(s).ok)
	t.eq(SetJobPriorityCommand.create("emp_player", "col_0001", dup).validate(s).reason_key, "error.job_priority.not_permutation")
	t.eq(SetJobPriorityCommand.create("emp_player", "col_0001", short).validate(s).reason_key, "error.job_priority.not_permutation")
	SetJobPriorityCommand.create("emp_player", "col_0001", good).apply(s)
	t.eq(s.colonies["col_0001"].job_priority, good)


func test_registry_round_trip(t: T) -> void:
	var order: Array[String] = ["clerks", "food", "energy", "minerals", "alloys", "research"]
	var cmds: Array[Command] = [
		RenameColonyCommand.create("emp_player", "col_0001", "Aster Prime"),
		SetJobPriorityCommand.create("emp_player", "col_0001", order),
	]
	for c: Command in cmds:
		var back: Command = CommandRegistry.from_dict(CanonicalJson.parse(CanonicalJson.stringify(c.to_dict())))
		t.ne(back, null, c.type_id())
		t.eq(back.to_dict(), c.to_dict())
	t.eq(CommandRegistry.from_dict({"type": "nonsense"}), null)


func test_queue_validates_against_preview_and_undoes(t: T) -> void:
	var s: GameState = TinyState.build()
	var q: CommandQueue = CommandQueue.new(s)
	t.ok(q.submit(RenameColonyCommand.create("emp_player", "col_0001", "One")).ok)
	t.ok(q.submit(RenameColonyCommand.create("emp_player", "col_0001", "Two")).ok)
	var bad: Result = q.submit(RenameColonyCommand.create("emp_player", "col_0404", "Three"))
	t.not_ok(bad.ok)
	t.eq(bad.reason_key, "error.colony.not_found", "invalid orders say why")
	t.eq(q.size(), 2, "invalid orders are not queued")
	t.eq(q.preview().colonies["col_0001"].name, "Two")
	t.eq(s.colonies["col_0001"].name, "", "start-of-turn state untouched")
	var undone: Command = q.undo()
	t.eq((undone as RenameColonyCommand).new_name, "Two")
	t.eq(q.preview().colonies["col_0001"].name, "One")
	q.undo()
	t.eq(q.undo(), null, "nothing left to undo")
	t.eq(q.preview().colonies["col_0001"].name, "")
