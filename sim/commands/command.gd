class_name Command
extends RefCounted
## Base class for every order a player or AI can give. The UI submits commands through
## Game.submit(); the turn processor applies them in phase 1.
##
## Subclasses override type_id(), validate(), apply(), _payload() and _load_payload().
## validate() must not mutate state; apply() may assume validate() returned ok.

var empire_id: String = ""


func type_id() -> String:
	return ""


func validate(_state: GameState) -> Result:
	return Result.fail("error.command.unknown")


func apply(_state: GameState) -> void:
	pass


func to_dict() -> Dictionary:
	var d: Dictionary = _payload()
	d["type"] = type_id()
	d["empire_id"] = empire_id
	return d


func _payload() -> Dictionary:
	return {}


func _load_payload(_d: Dictionary) -> void:
	pass


## Shared check: the empire exists and owns the colony. Returns the colony or null with `out`
## filled with the failure.
static func owned_colony(state: GameState, p_empire_id: String, colony_id: String, out: Array[Result]) -> Colony:
	if not state.empires.has(p_empire_id):
		out.append(Result.fail("error.empire.not_found"))
		return null
	if not state.colonies.has(colony_id):
		out.append(Result.fail("error.colony.not_found"))
		return null
	var c: Colony = state.colonies[colony_id]
	if c.owner_id != p_empire_id:
		out.append(Result.fail("error.colony.not_owned"))
		return null
	return c
