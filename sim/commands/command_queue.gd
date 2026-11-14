class_name CommandQueue
extends RefCounted
## The player's orders for the current turn (§6.7). Each order is validated against the state as
## it will be after the earlier orders, applied to a preview copy so the UI can show the result,
## and can be undone until End Turn. The start-of-turn state is never touched.

var _base: GameState
var _preview: GameState
var _commands: Array[Command] = []


func _init(base: GameState) -> void:
	_base = base
	_preview = base.clone()


## Validates and queues a command. On failure nothing changes and the Result says why.
func submit(cmd: Command) -> Result:
	# Commands are mutable RefCounted objects. Capture the exact order shown in the preview;
	# later edits to the caller's instance must not silently alter the queued operation.
	var snapshot: Command = CommandRegistry.from_dict(cmd.to_dict()) if cmd != null else null
	if snapshot == null:
		return Result.fail("error.command.unknown")
	if snapshot.empire_id != _base.player_id:
		return Result.fail("error.command.not_player")
	var r: Result = snapshot.validate(_preview)
	if r.ok:
		snapshot.apply(_preview)
		_commands.append(snapshot)
	return r


## Removes the most recent command and rebuilds the preview. Returns it, or null if empty.
func undo() -> Command:
	if _commands.is_empty():
		return null
	var last: Command = _commands.pop_back()
	_preview = _base.clone()
	for cmd: Command in _commands:
		cmd.apply(_preview)
	return last


func clear() -> void:
	_commands.clear()
	_preview = _base.clone()


func base() -> GameState:
	return _base


## The state as it will be once every queued order is applied. Read-only for callers.
func preview() -> GameState:
	return _preview


func commands() -> Array[Command]:
	# Do not expose the mutable orders retained by the queue to UI, replay, or callers.
	var snapshots: Array[Command] = []
	for cmd: Command in _commands:
		snapshots.append(CommandRegistry.from_dict(cmd.to_dict()))
	return snapshots


func size() -> int:
	return _commands.size()
