class_name MoveFleetCommand
extends Command
## Orders an idle civilian fleet along a deterministic slowboat route.

const TYPE: String = "move_fleet"
var fleet_id: String = ""
var destination: String = ""


static func create(p_empire_id: String, p_fleet_id: String, p_destination: String) -> MoveFleetCommand:
	var command: MoveFleetCommand = MoveFleetCommand.new()
	command.empire_id = p_empire_id
	command.fleet_id = p_fleet_id
	command.destination = p_destination
	return command


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Travel.can_move(state, empire_id, fleet_id, destination)


func apply(state: GameState) -> void:
	state.fleets[fleet_id].path = Travel.route(state, fleet_id, destination)


func _payload() -> Dictionary:
	return {"fleet_id": fleet_id, "destination": destination}


func _load_payload(d: Dictionary) -> void:
	fleet_id = DictIO.str_of(d, "fleet_id")
	destination = DictIO.str_of(d, "destination")
