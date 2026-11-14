extends SceneTree
## Private long-horizon measurement, synthetic initial victory followed by legal commands only.

const OUT: String = "/workspace/starfire-evidence/m2f-stress"
var waits: Dictionary[String, int] = {}
var issued: Dictionary[String, int] = {}


func _queue(q: CommandQueue, cmd: Command) -> bool:
	var check: Result = q.submit(cmd)
	if not check.ok:
		waits[check.reason_key] = waits.get(check.reason_key, 0) + 1
		return false
	issued[cmd.type_id()] = issued.get(cmd.type_id(), 0) + 1
	return true


func _initialize() -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1, "normal")
	# Synthetic starting fixture: mark required objectives and let the ordinary rule grant victory.
	for d: Dictionary in Objectives.definitions(state):
		if DictIO.bool_of(d, "required"): state.objectives_done[DictIO.str_of(d, "id")] = state.turn
	Objectives.update(state, TurnResult.new())
	if state.outcome != GameState.OUTCOME_WON:
		_fail("synthetic fixture did not win")
		return
	var original_completed: int = state.outcome_turn
	var transition: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(state)
	if not transition.ok:
		_fail("continuation rejected: " + transition.error_key)
		return
	state = transition.state
	var start_hash: String = state.state_hash()
	var start_turn: int = state.turn
	var times_us: Array[int] = []
	var saves_checked: int = 0
	var largest_save: int = 0
	var started_auto: bool = false
	var violations: Array[String] = []
	var trace: FileAccess = FileAccess.open(OUT + "/turns.tsv", FileAccess.WRITE)
	trace.store_line("resolved_turn\tprocessor_ms\tstate_hash\toutcome\tcompleted_turn\tsave_bytes")
	for unused: int in range(200):
		if state.is_over(): break
		var q: CommandQueue = CommandQueue.new(state)
		var eid: String = state.player_id
		for ev: EventInstance in Events.pending_for(state, eid):
			var options: Array = DictIO.arr_of(Events.step_of(ev.chain, ev.step), "choices")
			for index: int in [2, 0, 1, 3]:
				if index < options.size() and Events.can_choose(q.preview(), eid, ev.id, index).ok:
					_queue(q, ChooseEventCommand.create(eid, ev.id, index))
					break
		for branch: String in Empire.BRANCHES:
			var rb: ResearchBranch = q.preview().player().research.get(branch, null)
			if rb != null and rb.card.is_empty() and not rb.hand.is_empty():
				_queue(q, PickResearchCommand.create(eid, branch, rb.hand[0]))
		for ship: Ship in state.ships_of(eid):
			if not state.fleets.has(ship.fleet_id): continue
			var f: Fleet = state.fleets[ship.fleet_id]
			if ship.is_busy() or not f.path.is_empty() or f.move_progress != 0: continue
			match Ships.role(ship):
				Ships.ROLE_SURVEY:
					if not started_auto:
						started_auto = _queue(q, SetAutoExploreCommand.create(eid, f.id, true))
				Ships.ROLE_CONSTRUCTION:
					if f.system_id != "sys_tessel":
						_queue(q, MoveFleetCommand.create(eid, f.id, "sys_tessel"))
					elif state.player().surveyed_planets.has("pl_tessel") and state.planets["pl_tessel"].colony_id.is_empty():
						_queue(q, BuildOutpostCommand.create(eid, ship.id, "pl_tessel", "minerals"))
				Ships.ROLE_COLONY:
					if f.system_id != "sys_vesper":
						_queue(q, MoveFleetCommand.create(eid, f.id, "sys_vesper"))
					elif state.player().surveyed_planets.has("pl_vesper") and state.planets["pl_vesper"].colony_id.is_empty():
						_queue(q, ColoniseCommand.create(eid, ship.id, "pl_vesper"))
		var turn_before: int = state.turn
		var started: int = Time.get_ticks_usec()
		var result: TurnResult = TurnProcessor.run(state, q.commands())
		var elapsed: int = Time.get_ticks_usec() - started
		times_us.append(elapsed)
		state = result.state
		if not result.rejected.is_empty(): violations.append("accepted order rejected: " + str(result.rejected))
		var errors: Array[String] = Invariants.check(state)
		if not errors.is_empty(): violations.append("invariants: " + str(errors))
		if state.outcome == GameState.OUTCOME_WON: violations.append("repeat victory")
		if ExpeditionContinuation.completion_turn(state) != original_completed: violations.append("original victory turn changed")
		for item: ReportItem in result.report_items:
			if item.text_key == "report.scenario_won": violations.append("repeat victory report")
		var serialized: String = SaveSerializer.to_text(state, "m2f-stress")
		var size: int = serialized.to_utf8_buffer().size()
		largest_save = maxi(largest_save, size)
		if times_us.size() % 10 == 0 or state.is_over() or times_us.size() == 200:
			var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(serialized)
			if not loaded.ok or loaded.state.state_hash() != state.state_hash(): violations.append("save round-trip mismatch")
			saves_checked += 1
		trace.store_line("%d\t%.3f\t%s\t%s\t%d\t%d" % [turn_before, float(elapsed) / 1000.0, state.state_hash(), state.outcome, ExpeditionContinuation.completion_turn(state), size])
		if not violations.is_empty(): break
	var ordered: Array[int] = times_us.duplicate()
	ordered.sort()
	var p95_index: int = maxi(0, Fx.div_ceil(ordered.size() * 95, 100) - 1)
	var total: int = 0
	for sample: int in times_us: total += sample
	var last_save: String = SaveSerializer.to_text(state, "m2f-stress")
	var save_file: FileAccess = FileAccess.open(OUT + "/last-save.json", FileAccess.WRITE)
	save_file.store_string(last_save)
	var summary: Dictionary = {
		"fixture": "Synthetic turn-1 victory in m2a_expedition; required objectives premarked, normal Objectives.update and ExpeditionContinuation.begin; seed 1 normal difficulty.",
		"policy": "After fixture: legal queued orders only; choose free event choice when valid, pick first offered card in each branch, start one survey automation, send builder to Tessel minerals and colony ship to Vesper. No direct state edits after initial fixture.",
		"limits": "One machine, one seed and one simple policy. Measurements cover TurnProcessor.run only, exclude UI/frame rendering, command preparation, invariant checks and save serialization.",
		"start_turn": start_turn, "starting_state_hash": start_hash, "original_win_turn": original_completed,
		"turns_processed": times_us.size(), "last_resolved_turn": state.turn - 1, "next_turn": state.turn,
		"outcome": state.outcome, "outcome_turn": state.outcome_turn, "final_hash": state.state_hash(),
		"processor_mean_ms": float(total) / float(maxi(1, times_us.size())) / 1000.0,
		"processor_p95_ms": float(ordered[p95_index]) / 1000.0 if not ordered.is_empty() else 0.0,
		"processor_max_ms": float(ordered.back()) / 1000.0 if not ordered.is_empty() else 0.0,
		"last_save_bytes": last_save.to_utf8_buffer().size(), "max_save_bytes": largest_save,
		"verified_save_round_trips": saves_checked, "issued_commands": issued, "validation_waits": waits,
		"violations": violations,
	}
	var file: FileAccess = FileAccess.open(OUT + "/summary.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	print(JSON.stringify(summary, "  "))
	quit(0 if violations.is_empty() else 1)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
