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
## Monotonically identifies a session, including loads and games with the same seed.
var session_serial: int = 0
var _continuation_saving: bool = false
var _continuation_generation: int = 0
var _turn_resolving: bool = false


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
	# A load or new game invalidates any outstanding browser acknowledgement.
	_continuation_generation += 1
	_continuation_saving = false
	session_serial += 1
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
	if _continuation_saving:
		return Result.fail("error.continue.saving")
	if queue == null:
		return Result.fail("error.command.unknown")
	if cmd != null and state != null and cmd.empire_id != state.player_id:
		return Result.fail("error.command.not_player")
	var r: Result = queue.submit(cmd)
	if r.ok:
		orders_changed.emit()
	return r


func undo() -> Command:
	if _continuation_saving:
		return null
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
	if _turn_resolving or _continuation_saving or state == null or queue == null or state.is_over():
		return null
	_turn_resolving = true
	var r: TurnResult = TurnProcessor.run(state, queue.commands())
	state = r.state
	queue = CommandQueue.new(state)
	last_result = r
	turn_resolved.emit(r)
	orders_changed.emit()
	_turn_resolving = false
	return r


## Continue an opted-in victory without advancing a turn. Persist the replacement auto-save
## before changing the live session; a failure leaves the current session untouched.
func continue_expedition(expected_state: GameState, expected_session: int) -> Result:
	if _continuation_saving:
		return Result.fail("error.continue.saving")
	if expected_state == null or state != expected_state or session_serial != expected_session:
		return Result.fail("error.continue.stale")
	if queue == null or queue.size() != 0:
		return Result.fail("error.continue.pending_orders")
	var transition: ExpeditionContinuation.Transition = ExpeditionContinuation.begin(state)
	if not transition.ok:
		return Result.fail(transition.error_key)
	if Settings.persist and OS.has_feature("web") and not OS.is_userfs_persistent():
		return Result.fail("error.continue.save_failed")
	_continuation_generation += 1
	var generation: int = _continuation_generation
	_continuation_saving = true
	var graphics: Dictionary = Worlds.save_fields(state)
	if Settings.persist:
		var slot: String = "%s_%d" % [SaveService.KIND_AUTO, transition.state.turn % SaveService.AUTO_RING]
		var path: String = SaveService._path(slot)
		if SaveService.save(slot, transition.state) != OK:
			_continuation_saving = false
			return Result.fail("error.continue.save_failed")
		if OS.has_feature("web"):
			var written: String = FileAccess.get_file_as_string(path)
			if written.is_empty():
				_continuation_saving = false
				return Result.fail("error.continue.web_unconfirmed")
			return await _finish_web_continuation(expected_state, expected_session, generation, transition.state, graphics, path, written, WebSaveVerifier.committed)
	_continuation_saving = false
	resume(transition.state, str(graphics.get("presentation", "")), str(graphics.get("presentation_overlay", "")), false)
	return Result.success()



## The verifier is passed as a callable so the asynchronous lifecycle can be exercised without
## faking the browser. Only the current operation may release its busy state or resume a game.
func _finish_web_continuation(expected_state: GameState, expected_session: int, generation: int, next_state: GameState, graphics: Dictionary, path: String, written: String, verifier: Callable) -> Result:
	var committed: bool = await verifier.call(path, written)
	if generation != _continuation_generation or not _continuation_saving:
		return Result.fail("error.continue.stale")
	var stale: bool = state != expected_state or session_serial != expected_session or queue == null or queue.size() != 0
	_continuation_saving = false
	if stale:
		return Result.fail("error.continue.stale")
	if not committed:
		return Result.fail("error.continue.web_unconfirmed")
	resume(next_state, str(graphics.get("presentation", "")), str(graphics.get("presentation_overlay", "")), false)
	return Result.success()
