class_name ActivateOrdinanceCommand
extends Command
## Activates an ordinance in a free slot, paying its influence (§5.11).

const TYPE: String = "activate_ordinance"

var ordinance_id: String = ""


static func create(p_empire_id: String, p_ordinance_id: String) -> ActivateOrdinanceCommand:
	var c: ActivateOrdinanceCommand = ActivateOrdinanceCommand.new()
	c.empire_id = p_empire_id
	c.ordinance_id = p_ordinance_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Ordinances.can_activate(state, empire_id, ordinance_id)


func apply(state: GameState) -> void:
	Ordinances.activate(state, state.empires[empire_id], ordinance_id)


func _payload() -> Dictionary:
	return {"ordinance_id": ordinance_id}


func _load_payload(d: Dictionary) -> void:
	ordinance_id = DictIO.str_of(d, "ordinance_id")
