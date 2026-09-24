class_name GoldenScript
extends RefCounted
## The fixed seed and command script behind the golden hash tests. The test compares against
## tests/golden/*.json; tools/regen_golden.gd rewrites those files (deliberately, with a reason).

const TINY_PATH: String = "res://tests/golden/tiny_hashes.json"
const TINY_SEED: int = 20970401
const TINY_TURNS: int = 12


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
