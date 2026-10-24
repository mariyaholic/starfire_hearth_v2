extends Node
## The game session and command bus (§9.3): loaded content, the state at the start of this turn,
## the player's queued orders, and End Turn. Screens submit commands here and read state and
## TurnResults; they never mutate state themselves.

signal orders_changed
signal turn_resolved(result: TurnResult)
signal session_started

var db: ContentDb
var state: GameState = null
var queue: CommandQueue = null
var last_result: TurnResult = null
var presentation: String = ""
var presentation_overlay: String = ""
var fresh_appearance: bool = false


func _init() -> void:
	db = Content.db()
	for e: String in db.errors:
		push_error("Game data: " + e)


func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func new_game(scenario_id: String, game_seed: int, difficulty_id: String = "normal") -> void:
	resume(ScenarioLoader.build(db, scenario_id, game_seed, difficulty_id), "", "", true)


## Takes over a state (a new game or a loaded save) with an empty order queue.
func resume(s: GameState, graphics: String = "", graphics_overlay: String = "", fresh: bool = false) -> void:
	state = s
	presentation = graphics
	presentation_overlay = graphics_overlay
	fresh_appearance = fresh
	queue = CommandQueue.new(state)
	last_result = null
	session_started.emit()
	orders_changed.emit()


func has_game() -> bool:
	return state != null


## Validates and queues an order; the Result says why when it is refused.
func submit(cmd: Command) -> Result:
	if queue == null:
		return Result.fail("error.command.unknown")
	var r: Result = queue.submit(cmd)
	if r.ok:
		orders_changed.emit()
	return r


func undo() -> Command:
	if queue == null:
		return null
	var c: Command = queue.undo()
	if c != null:
		orders_changed.emit()
	return c


## The state as it will be after this turn's orders (what screens should display).
func view() -> GameState:
	return queue.preview() if queue != null else state


func end_turn() -> TurnResult:
	var r: TurnResult = TurnProcessor.run(state, queue.commands())
	state = r.state
	queue = CommandQueue.new(state)
	last_result = r
	turn_resolved.emit(r)
	orders_changed.emit()
	return r
