class_name ExpeditionContinuation
extends RefCounted
## Converts an authoritative preview victory into an independent playable continuation.
## The original win is recorded in existing integer flags; no turn or economy phase runs here.

const FLAG_CONTINUED: String = "expedition:continued"
const FLAG_COMPLETED_TURN: String = "expedition:completed_turn"


class Transition:
	extends RefCounted
	var ok: bool = false
	var error_key: String = ""
	var state: GameState = null


static func supported(state: GameState) -> bool:
	if state == null or state.scenario_id != "m2a_expedition":
		return false
	var scenario: Dictionary = Objectives.scenario(state)
	return typeof(scenario.get("allow_post_victory")) == TYPE_BOOL and scenario["allow_post_victory"]


## Recognition is scoped to the opted-in scenario and requires a consistent original win turn.
static func is_continued(state: GameState) -> bool:
	return supported(state) and state.flags.get(FLAG_CONTINUED, 0) == 1 and state.flags.has(FLAG_COMPLETED_TURN) and state.flags[FLAG_COMPLETED_TURN] >= 1 and state.flags[FLAG_COMPLETED_TURN] <= state.turn


## Original victory turn for a valid continuation; zero when no continuation exists.
static func completion_turn(state: GameState) -> int:
	return state.flags[FLAG_COMPLETED_TURN] if is_continued(state) else 0


static func can_continue(state: GameState) -> Result:
	if not supported(state):
		return Result.fail("error.continue.unsupported")
	if state.flags.has(FLAG_CONTINUED) or state.flags.has(FLAG_COMPLETED_TURN):
		return Result.fail("error.continue.already_continued" if is_continued(state) else "error.continue.invalid_victory")
	if state.outcome != GameState.OUTCOME_WON:
		return Result.fail("error.continue.not_won")
	if state.player() == null or state.outcome_turn < 1 or state.outcome_turn > state.turn:
		return Result.fail("error.continue.invalid_victory")
	return Result.success()


static func begin(state: GameState) -> Transition:
	var transition: Transition = Transition.new()
	var validation: Result = can_continue(state)
	if not validation.ok:
		transition.error_key = validation.reason_key
		return transition
	transition.state = state.clone()
	transition.state.flags[FLAG_CONTINUED] = 1
	transition.state.flags[FLAG_COMPLETED_TURN] = state.outcome_turn
	transition.state.outcome = GameState.OUTCOME_NONE
	transition.state.outcome_turn = 0
	transition.state.outcome_reason = ""
	transition.ok = true
	return transition
