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


func test_every_command_type_round_trips(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	var cmds: Array[Command] = [
		PlaceDistrictCommand.create("emp_player", cid, 8, "research", "society"),
		UpgradeDistrictCommand.create("emp_player", cid, 2),
		DemolishCommand.create("emp_player", cid, 4),
		BuildBuildingCommand.create("emp_player", cid, 9, "park_commons"),
		BuildShipCommand.create("emp_player", cid, "colony_ship"),
		CancelBuildCommand.create("emp_player", cid, "bld_0001"),
		MoveBuildUpCommand.create("emp_player", cid, "bld_0002"),
		RushBuildCommand.create("emp_player", cid, "bld_0001"),
		PickResearchCommand.create("emp_player", "society", "hydroponics"),
		RerollResearchCommand.create("emp_player", "physics"),
		ActivateOrdinanceCommand.create("emp_player", "festival"),
		CancelOrdinanceCommand.create("emp_player", "festival"),
		SetGovernorCommand.create("emp_player", cid, true, "research", 7000),
		VetoPlanCommand.create("emp_player", cid, "district:mining"),
		SurveyCommand.create("emp_player", "shp_0002", "pl_brume"),
		BuildOutpostCommand.create("emp_player", "shp_0001", "pl_dross", "research"),
		ColoniseCommand.create("emp_player", "shp_0003", "pl_brume"),
		ChooseEventCommand.create("emp_player", "evt_0001", 2),
		AcknowledgeCommand.create("emp_player", "t_food"),
		TradeCommand.create("emp_player", "alloys", 3, true),
	]
	var types: Dictionary[String, bool] = {}
	for cmd: Command in cmds:
		var d: Dictionary = cmd.to_dict()
		var back: Command = CommandRegistry.from_dict(d)
		t.ne(back, null, cmd.type_id())
		if back != null:
			t.eq(back.to_dict(), d, cmd.type_id())
		types[cmd.type_id()] = true
	for type: String in CommandRegistry.known_types():
		if type != RenameColonyCommand.TYPE and type != SetJobPriorityCommand.TYPE:
			t.ok(types.has(type), "%s is covered" % type)


func test_orders_validate_against_the_preview(t: T) -> void:
	var s: GameState = S1.build()
	var q: CommandQueue = CommandQueue.new(s)
	var cid: String = S1.aster(s).id
	for slot: int in [8, 9, 10, 11]:
		t.ok(q.submit(PlaceDistrictCommand.create("emp_player", cid, slot, "agriculture")).ok)
	t.eq(q.submit(PlaceDistrictCommand.create("emp_player", cid, 12, "agriculture")).reason_key, "error.build.cannot_afford", "the fifth farm costs more than is left")
	q.undo()
	t.eq(q.preview().player().stock_of("minerals"), 25000 - 3 * 6000, "undo refunds through the rebuilt preview")
	s.player().stock["minerals"] = 100000
	var q2: CommandQueue = CommandQueue.new(s)
	for slot2: int in [8, 9, 10, 11, 12]:
		t.ok(q2.submit(PlaceDistrictCommand.create("emp_player", cid, slot2, "agriculture")).ok)
	t.eq(q2.submit(PlaceDistrictCommand.create("emp_player", cid, 13, "agriculture")).reason_key, "error.build.queue_full")
