class_name StopFleetCommand
extends Command
## Finish the current lane and stop at the next system, preserving elapsed progress.

const TYPE: String = "stop_fleet"
var fleet_id: String = ""


static func create(p_empire_id: String, p_fleet_id: String) -> StopFleetCommand:
	var command: StopFleetCommand = StopFleetCommand.new()
	command.empire_id = p_empire_id
	command.fleet_id = p_fleet_id
	return command


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Travel.can_stop(state, empire_id, fleet_id)


func apply(state: GameState) -> void:
	Travel.stop_next(state, fleet_id)


func _payload() -> Dictionary:
	return {"fleet_id": fleet_id}


func _load_payload(d: Dictionary) -> void:
	fleet_id = DictIO.str_of(d, "fleet_id")
