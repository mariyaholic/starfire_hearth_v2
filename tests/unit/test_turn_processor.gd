extends RefCounted
## The turn phase contract (§9.4), purity of run(), and determinism.

const EXPECTED_PHASES: Array[String] = [
	"commands", "construction", "production", "food_growth", "research", "movement", "combat",
	"occupation", "stability_edicts", "diplomacy", "noise", "events", "victory", "report",
]


func test_phase_order_is_the_contract(t: T) -> void:
	t.eq(TurnProcessor.PHASES, EXPECTED_PHASES)
	var r: TurnResult = TurnProcessor.run(TinyState.build(), [])
	t.eq(r.phase_log, EXPECTED_PHASES, "phases ran in contract order")


func test_run_does_not_mutate_input(t: T) -> void:
	var s: GameState = TinyState.build()
	var before: String = s.state_hash()
	var cmds: Array[Command] = [RenameColonyCommand.create("emp_player", "col_0001", "Changed")]
	var r: TurnResult = TurnProcessor.run(s, cmds)
	t.eq(s.state_hash(), before)
	t.eq(r.state.colonies["col_0001"].name, "Changed")
	t.eq(r.state.turn, s.turn + 1)


func test_same_inputs_same_hash(t: T) -> void:
	var cmds_a: Array[Command] = [RenameColonyCommand.create("emp_player", "col_0001", "Same")]
	var cmds_b: Array[Command] = [RenameColonyCommand.create("emp_player", "col_0001", "Same")]
	var a: TurnResult = TurnProcessor.run(TinyState.build(), cmds_a)
	var b: TurnResult = TurnProcessor.run(TinyState.build(), cmds_b)
	t.eq(a.state_hash, b.state_hash)
	t.eq(a.state_hash, a.state.state_hash(), "result hash is the hash of the new state")


func test_rejected_player_order_is_reported(t: T) -> void:
	var cmds: Array[Command] = [RenameColonyCommand.create("emp_player", "col_0404", "Nope")]
	var r: TurnResult = TurnProcessor.run(TinyState.build(), cmds)
	t.eq(r.rejected.size(), 1)
	var rejections: Array[ReportItem] = []
	for it: ReportItem in r.report_items:
		if it.text_key == "report.order_rejected":
			rejections.append(it)
	t.eq(rejections.size(), 1)
	if rejections.size() == 1:
		t.eq(rejections[0].args["reason_key"], "error.colony.not_found")
		t.eq(rejections[0].severity, ReportItem.SEVERITY_WARNING)


func test_report_builder_top_three_is_deterministic(t: T) -> void:
	var items: Array[ReportItem] = [
		ReportItem.make(ReportItem.CATEGORY_STORY, 50, "a"),
		ReportItem.make(ReportItem.CATEGORY_COLONIES, 90, "b").with_severity(ReportItem.SEVERITY_WARNING),
		ReportItem.make(ReportItem.CATEGORY_RESEARCH, 90, "c"),
		ReportItem.make(ReportItem.CATEGORY_FLEETS, 90, "d").with_severity(ReportItem.SEVERITY_CRITICAL),
		ReportItem.make(ReportItem.CATEGORY_COLONIES, 10, "e"),
	]
	var top: Array[ReportItem] = ReportBuilder.top(items)
	var keys: Array[String] = []
	for it: ReportItem in top:
		keys.append(it.text_key)
	t.eq(keys, ["d", "b", "c"], "importance, then severity, then category order")
	var groups: Dictionary[String, Array] = ReportBuilder.grouped(items)
	t.eq(groups.keys(), ["colonies", "research", "fleets", "story"])
	t.eq(groups["colonies"][0].text_key, "b")
	t.ok(items[3].blocks_end_turn, "critical items block End Turn")
