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
	var r: Result = cmd.validate(_preview)
	if r.ok:
		cmd.apply(_preview)
		_commands.append(cmd)
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
	return _commands.duplicate()


func size() -> int:
	return _commands.size()
