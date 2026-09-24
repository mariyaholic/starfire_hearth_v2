class_name AiPlayer
extends RefCounted
## Utility AI (§5.8). It generates candidates from the same command list the player uses and
## scores them with personality weights. Not implemented before M3: every AI empire passes.


## Commands for one AI empire this turn, decided from the start-of-turn state.
static func decide(_state: GameState, _empire_id: String) -> Array[Command]:
	return []
