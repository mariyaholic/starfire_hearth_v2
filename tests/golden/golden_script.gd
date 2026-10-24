class_name GoldenScript
extends RefCounted
## The fixed seed and command script behind the golden hash tests. The test compares against
## tests/golden/*.json; tools/regen_golden.gd rewrites those files (deliberately, with a reason).

const TINY_PATH: String = "res://tests/golden/tiny_hashes.json"
const TINY_SEED: int = 20970401
const TINY_TURNS: int = 12
const S1_PATH: String = "res://tests/golden/s1_hashes.json"
const S1_SEED: int = 4242
const S1_TURNS: int = 24
## The turn after which the Scenario 1 run is frozen as the schema's fixture save.
const S1_FIXTURE_TURN: int = 16


## Per-turn state hashes for the tiny fixture: element 0 is the start state, element i the state
## after turn i.
static func tiny_hashes() -> Array[String]:
	var state: GameState = TinyState.build(TINY_SEED)
	var hashes: Array[String] = [state.state_hash()]
	for turn in TINY_TURNS:
		var r: TurnResult = TurnProcessor.run(state, commands_for(turn))
		state = r.state
		hashes.append(r.state_hash)
	return hashes


## Per-turn hashes of Scenario 1 under a fixed script of M1 orders (builds, research, a survey,
## an event answer, an ordinance, a governor).
static func s1_hashes() -> Array[String]:
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", S1_SEED)
	var hashes: Array[String] = [state.state_hash()]
	for turn in S1_TURNS:
		var r: TurnResult = TurnProcessor.run(state, s1_commands(turn, state))
		state = r.state
		hashes.append(r.state_hash)
	return hashes


## The Scenario 1 state after S1_FIXTURE_TURN scripted turns.
static func s1_state(turns: int = S1_FIXTURE_TURN) -> GameState:
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", S1_SEED)
	for turn in turns:
		state = TurnProcessor.run(state, s1_commands(turn, state)).state
	return state


static func s1_commands(turn: int, state: GameState) -> Array[Command]:
	const P: String = "emp_player"
	var cmds: Array[Command] = []
	var cap: String = state.player().capital_id
	match turn:
		0:
			cmds.append(PlaceDistrictCommand.create(P, cap, 8, "industry"))
			cmds.append(PickResearchCommand.create(P, "society", "frontier_medicine"))
			cmds.append(PickResearchCommand.create(P, "physics", "sensor_arrays"))
			for sh: Ship in state.ships_of(P):
				if sh.hull == "survey_probe":
					cmds.append(SurveyCommand.create(P, sh.id, "pl_brume"))
		1:
			cmds.append(PlaceDistrictCommand.create(P, cap, 9, "research", "society"))
		3:
			cmds.append(ActivateOrdinanceCommand.create(P, "festival"))
		6:
			cmds.append(SetGovernorCommand.create(P, cap, true, "balanced", 5000))
		9:
			cmds.append(RenameColonyCommand.create(P, cap, "Aster Hearth"))
	for ev: EventInstance in state.events_pending:
		cmds.append(ChooseEventCommand.create(P, ev.id, 0))
	if turn == 5:
		cmds.append(RenameColonyCommand.create(P, "col_0404", "Rejected"))
	return cmds


## The scripted orders for one turn (turn index from 0). Includes one order that is rejected.
static func commands_for(turn: int) -> Array[Command]:
	var cmds: Array[Command] = []
	if turn % 3 == 0:
		cmds.append(RenameColonyCommand.create("emp_player", "col_0001", "Hearth %d" % turn))
	if turn % 4 == 1:
		var order: Array[String] = Colony.DEFAULT_JOB_PRIORITY.duplicate()
		order.reverse()
		cmds.append(SetJobPriorityCommand.create("emp_player", "col_0001", order))
	if turn == 5:
		cmds.append(RenameColonyCommand.create("emp_player", "col_0404", "Rejected"))
	return cmds
