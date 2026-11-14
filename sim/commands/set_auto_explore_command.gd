class_name SetAutoExploreCommand
extends Command
## Enable or disable future assignments without changing any current task or route.

const TYPE: String = "set_auto_explore"
var fleet_id: String = ""
var enable: bool = false


static func create(p_empire_id: String, p_fleet_id: String, p_enable: bool) -> SetAutoExploreCommand:
	var command: SetAutoExploreCommand = SetAutoExploreCommand.new()
	command.empire_id = p_empire_id
	command.fleet_id = p_fleet_id
	command.enable = p_enable
	return command


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return AutoExplore.can_set(state, empire_id, fleet_id, enable)


func apply(state: GameState) -> void:
	AutoExplore.set_enabled(state, empire_id, fleet_id, enable)


func _payload() -> Dictionary:
	return {"fleet_id": fleet_id, "enable": enable}


func _load_payload(d: Dictionary) -> void:
	fleet_id = DictIO.str_of(d, "fleet_id")
	enable = DictIO.bool_of(d, "enable")
