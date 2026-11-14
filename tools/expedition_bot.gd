extends SceneTree
## Reproducible preview playthrough using only command validation and turn processing.
## Use -- --seed N --trace to print the full per-turn hash path for determinism comparisons.

var submission_error: bool = false
var waiting: Dictionary[String, int] = {}

## Wait for unaffordable or not-yet-reachable orders; accepted previews must resolve unchanged.
func _try(q: CommandQueue, cmd: Command) -> void:
	var check: Result = cmd.validate(q.preview())
	if not check.ok:
		waiting[check.reason_key] = waiting.get(check.reason_key, 0) + 1
		return
	var accepted: Result = q.submit(cmd)
	if not accepted.ok:
		printerr("preview rejected validated order: " + accepted.reason_key)
		submission_error = true

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed: int = 1
	var seed_index: int = args.find("--seed")
	if seed_index >= 0 and seed_index + 1 < args.size(): seed = int(args[seed_index + 1])
	var trace: bool = args.has("--trace")
	var choice: int = 2
	var choice_index: int = args.find("--choice")
	if choice_index >= 0 and choice_index + 1 < args.size(): choice = int(args[choice_index + 1])
	if choice < 0 or choice > 2:
		printerr("--choice must be 0, 1 or 2")
		quit(1)
		return
	var started_auto: bool = false
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", seed, "normal")
	if trace: print("turn=%d hash=%s" % [state.turn, state.state_hash()])
	for unused: int in range(100):
		if state.is_over(): break
		var q: CommandQueue = CommandQueue.new(state)
		var eid: String = state.player_id
		for event: EventInstance in Events.pending_for(state, eid):
			_try(q, ChooseEventCommand.create(eid, event.id, choice))
		for ship: Ship in state.ships_of(eid):
			var f: Fleet = state.fleets[ship.fleet_id]
			if ship.is_busy() or not f.path.is_empty(): continue
			match Ships.role(ship):
				Ships.ROLE_SURVEY:
					if not started_auto:
						_try(q, SetAutoExploreCommand.create(eid, f.id, true))
						started_auto = AutoExplore.enabled(q.preview(), f.id)
				Ships.ROLE_CONSTRUCTION:
					if f.system_id != "sys_tessel": _try(q, MoveFleetCommand.create(eid, f.id, "sys_tessel"))
					elif state.player().surveyed_planets.has("pl_tessel") and state.planets["pl_tessel"].colony_id.is_empty():
						_try(q, BuildOutpostCommand.create(eid, ship.id, "pl_tessel", "minerals"))
				Ships.ROLE_COLONY:
					if f.system_id != "sys_vesper": _try(q, MoveFleetCommand.create(eid, f.id, "sys_vesper"))
					elif state.player().surveyed_planets.has("pl_vesper"): _try(q, ColoniseCommand.create(eid, ship.id, "pl_vesper"))
		var preview: GameState = q.preview()
		if preview.planets["pl_vesper"].colony_id != "":
			var c: Colony = preview.colonies[preview.planets["pl_vesper"].colony_id]
			if c.queue.is_empty() and c.districts.size() < 6:
				var slots: Array[int] = ColonyRules.free_slots(c, preview.planets[c.planet_id])
				if not slots.is_empty():
					var types: Array[String] = ["habitation", "agriculture", "mining", "energy", "habitation", "agriculture"]
					_try(q, PlaceDistrictCommand.create(eid, c.id, slots[0], types[c.districts.size()]))
		var result: TurnResult = TurnProcessor.run(state, q.commands())
		if submission_error or not result.rejected.is_empty():
			printerr("command rejection on turn %d: %s" % [state.turn, str(result.rejected)])
			quit(1)
			return
		state = result.state
		if trace: print("turn=%d hash=%s" % [state.turn, state.state_hash()])
		var problems: Array[String] = Invariants.check(state)
		if not problems.is_empty():
			printerr("invariant failure on turn %d: %s" % [state.turn, str(problems)])
			quit(1)
			return
	var expected_flag: String = ["m2a_halden_salvage", "m2a_halden_study", "m2a_halden_left_intact"][choice]
	if not state.flags.has(expected_flag):
		printerr("requested Halden choice did not resolve")
		quit(1)
		return
	print("validation waits: " + str(waiting))
	print("expedition seed=%d outcome=%s turn=%d hash=%s" % [seed, state.outcome, state.turn, state.state_hash()])
	for status: Objectives.Status in Objectives.statuses(state):
		print("%s: %d/%d done=%s" % [status.id, status.progress, status.target, str(status.done)])
	quit(0 if state.outcome == GameState.OUTCOME_WON else 1)
