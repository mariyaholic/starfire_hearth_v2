class_name S1
extends RefCounted
## Scenario 1 as tests use it: the real start state from data, and small helpers to reach into it.

const ID: String = "s1_first_light"
const PLAYER: String = "emp_player"


static func build(game_seed: int = 7, difficulty: String = "normal") -> GameState:
	return ScenarioLoader.build(Content.db(), ID, game_seed, difficulty)


static func aster(s: GameState) -> Colony:
	return s.colonies[s.player().capital_id]


static func ship(s: GameState, hull: String) -> Ship:
	for sh: Ship in s.ships_of(PLAYER):
		if sh.hull == hull:
			return sh
	return null


## Runs `n` turns with no orders and returns the last result.
static func advance(s: GameState, n: int) -> TurnResult:
	var r: TurnResult = null
	var state: GameState = s
	for i in n:
		r = TurnProcessor.run(state, [])
		state = r.state
	return r


## Runs one turn with the given orders.
static func turn(s: GameState, cmds: Array[Command]) -> TurnResult:
	return TurnProcessor.run(s, cmds)


## True when every breakdown in the empire report sums exactly (§6.1).
static func all_verify(er: Economy.EmpireReport) -> bool:
	for res: String in er.net.keys():
		if not er.net[res].verify():
			return false
	for b: String in er.research.keys():
		if not er.research[b].verify():
			return false
	for cid: String in er.colonies.keys():
		var cr: Economy.ColonyReport = er.colonies[cid]
		if cr.housing != null and not cr.housing.verify():
			return false
	return er.decode.verify()
