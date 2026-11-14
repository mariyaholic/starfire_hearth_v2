extends SceneTree
## Reproducible preview playthrough through the real command queue and turn processor.
## --route default|shroud-first|vesper-first; --outpost energy|research (non-default routes).
## --choice 0|1|2 selects the same index at each discovery; --seed N and --trace replay paths.
## Non-default routes pick cards in every branch; --research-cards applies that policy to default.

var submission_error: bool = false
var waiting: Dictionary[String, int] = {}


func _try(q: CommandQueue, cmd: Command) -> bool:
	var check: Result = cmd.validate(q.preview())
	if not check.ok:
		waiting[check.reason_key] = waiting.get(check.reason_key, 0) + 1
		return false
	var accepted: Result = q.submit(cmd)
	if not accepted.ok:
		printerr("preview rejected validated order: " + accepted.reason_key)
		submission_error = true
	return accepted.ok


func _value(args: PackedStringArray, key: String, fallback: String) -> String:
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed: int = int(_value(args, "--seed", "1"))
	var trace: bool = args.has("--trace")
	var choice: int = int(_value(args, "--choice", "2"))
	var route: String = _value(args, "--route", "default")
	var outpost: String = _value(args, "--outpost", "energy")
	var pick_cards: bool = route != "default" or args.has("--research-cards")
	if choice < 0 or choice > 2 or not ["default", "shroud-first", "vesper-first"].has(route) or not ["energy", "research"].has(outpost):
		printerr("Use --choice 0|1|2 --route default|shroud-first|vesper-first --outpost energy|research")
		quit(1)
		return
	if route == "default" and args.has("--outpost"):
		printerr("--outpost applies to shroud-first and vesper-first; default builds the Tessel minerals outpost")
		quit(1)
		return
	var started_auto: bool = false
	var research_orders: int = 0
	var milestones: Dictionary[String, int] = {}
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", seed, "normal")
	var starting_techs: int = state.player().techs.size()
	var minimum_food: int = state.player().stock_of("food")
	var minimum_energy: int = state.player().stock_of("energy")
	if trace: print("turn=%d hash=%s" % [state.turn, state.state_hash()])
	for unused: int in range(160):
		if state.is_over(): break
		var q: CommandQueue = CommandQueue.new(state)
		var eid: String = state.player_id
		for event: EventInstance in Events.pending_for(state, eid):
			_try(q, ChooseEventCommand.create(eid, event.id, choice))
		if pick_cards:
			for branch: String in Empire.BRANCHES:
				var rb: ResearchBranch = q.preview().player().branch(branch)
				if rb.card.is_empty() and not rb.hand.is_empty():
					if _try(q, PickResearchCommand.create(eid, branch, rb.hand[0])):
						research_orders += 1
		for ship: Ship in state.ships_of(eid):
			var f: Fleet = state.fleets[ship.fleet_id]
			if ship.is_busy() or not f.path.is_empty(): continue
			match Ships.role(ship):
				Ships.ROLE_SURVEY:
					if route == "default":
						if not started_auto:
							_try(q, SetAutoExploreCommand.create(eid, f.id, true))
							started_auto = AutoExplore.enabled(q.preview(), f.id)
					else:
						var e: Empire = q.preview().player()
						var vesper_surveyed: bool = e.surveyed_planets.has("pl_vesper")
						var shroud_surveyed: bool = e.surveyed_planets.has("pl_shroud_giant")
						if route == "vesper-first" and not vesper_surveyed:
							_survey_system(q, eid, ship.id, f, "sys_vesper", "pl_vesper")
						elif not shroud_surveyed:
							if not e.known_systems.has("sys_vesper"):
								_try(q, MoveFleetCommand.create(eid, f.id, "sys_vesper"))
							else:
								_survey_system(q, eid, ship.id, f, "sys_shroud", "pl_shroud_giant")
						elif not vesper_surveyed:
							_survey_system(q, eid, ship.id, f, "sys_vesper", "pl_vesper")
						elif not started_auto:
							_try(q, SetAutoExploreCommand.create(eid, f.id, true))
							started_auto = AutoExplore.enabled(q.preview(), f.id)
				Ships.ROLE_CONSTRUCTION:
					var target_system: String = "sys_tessel" if route == "default" else "sys_shroud"
					var target_planet: String = "pl_tessel" if route == "default" else "pl_shroud_giant"
					var kind: String = "minerals" if route == "default" else outpost
					if f.system_id != target_system: _try(q, MoveFleetCommand.create(eid, f.id, target_system))
					elif state.player().surveyed_planets.has(target_planet) and state.planets[target_planet].colony_id.is_empty():
						_try(q, BuildOutpostCommand.create(eid, ship.id, target_planet, kind))
				Ships.ROLE_COLONY:
					if f.system_id != "sys_vesper": _try(q, MoveFleetCommand.create(eid, f.id, "sys_vesper"))
					elif state.player().surveyed_planets.has("pl_vesper") and state.planets["pl_vesper"].colony_id.is_empty():
						_try(q, ColoniseCommand.create(eid, ship.id, "pl_vesper"))
		var preview: GameState = q.preview()
		# For the two optional itineraries, keep the game open until the requested outpost exists.
		var allow_development: bool = route == "default" or not preview.planets["pl_shroud_giant"].colony_id.is_empty()
		if allow_development and preview.planets["pl_vesper"].colony_id != "":
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
		minimum_food = mini(minimum_food, state.player().stock_of("food"))
		minimum_energy = mini(minimum_energy, state.player().stock_of("energy"))
		_mark(milestones, "vesper_survey", state.player().surveyed_planets.has("pl_vesper"), state.turn - 1)
		_mark(milestones, "vesper_colony", not state.planets["pl_vesper"].colony_id.is_empty(), state.turn - 1)
		_mark(milestones, "shroud_visit", state.player().known_systems.has("sys_shroud"), state.turn - 1)
		if state.planets.has("pl_shroud_giant"):
			_mark(milestones, "shroud_survey", state.player().surveyed_planets.has("pl_shroud_giant"), state.turn - 1)
			_mark(milestones, "shroud_outpost", not state.planets["pl_shroud_giant"].colony_id.is_empty(), state.turn - 1)
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
	if route != "default":
		var expected_shroud: String = ["m2a_shroud_salvage", "m2a_shroud_supplies", "m2a_shroud_honour"][choice]
		if not state.flags.has(expected_shroud) or not milestones.has("shroud_survey") or not milestones.has("shroud_outpost"):
			printerr("requested Shroud decision, survey and outpost did not complete")
			quit(1)
			return
		var shroud_colony: Colony = state.colonies[state.planets["pl_shroud_giant"].colony_id]
		if shroud_colony.outpost_kind != outpost:
			printerr("requested outpost or research orders did not complete")
			quit(1)
			return
		var report: Economy.ColonyReport = Economy.colony(state, shroud_colony)
		var outpost_yield: int = report.research["physics"].total if outpost == "research" else report.net_of("energy")
		print("shroud outpost=%s yield=%d research_orders=%d techs_completed=%d" % [outpost, outpost_yield, research_orders, state.player().techs.size() - starting_techs])
	if pick_cards and (research_orders == 0 or state.player().techs.size() <= starting_techs):
		printerr("requested research policy did not select and complete a technology")
		quit(1)
		return
	var final_economy: Economy.EmpireReport = Economy.empire(state, state.player_id)
	print("policy: research_cards=%s development_waits_for_shroud_outpost=%s" % [str(pick_cards), str(route != "default")])
	print("economy (centi-units; minima after turn): min_food=%d min_energy=%d final_food_net=%d final_energy_net=%d final_research_total=%d techs_completed=%d" % [minimum_food, minimum_energy, final_economy.net_of("food"), final_economy.net_of("energy"), final_economy.research_total(), state.player().techs.size() - starting_techs])
	print("milestones: " + str(milestones))
	if seed == 1 and route == "default" and not pick_cards:
		print("pre-Shroud seed 1 baseline: Vesper survey=21 colony=22; matches=%s" % str(milestones.get("vesper_survey", 0) == 21 and milestones.get("vesper_colony", 0) == 22))
	print("validation waits: " + str(waiting))
	print("expedition seed=%d route=%s outcome=%s turn=%d hash=%s" % [seed, route, state.outcome, state.turn, state.state_hash()])
	for status: Objectives.Status in Objectives.statuses(state):
		print("%s: %d/%d done=%s" % [status.id, status.progress, status.target, str(status.done)])
	quit(0 if state.outcome == GameState.OUTCOME_WON else 1)


func _survey_system(q: CommandQueue, eid: String, ship_id: String, fleet: Fleet, system_id: String, planet_id: String) -> void:
	if fleet.system_id != system_id:
		_try(q, MoveFleetCommand.create(eid, fleet.id, system_id))
	else:
		_try(q, SurveyCommand.create(eid, ship_id, planet_id))


func _mark(milestones: Dictionary[String, int], key: String, condition: bool, turn: int) -> void:
	if condition and not milestones.has(key):
		milestones[key] = turn
