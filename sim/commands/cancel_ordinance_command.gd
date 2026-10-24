class_name CancelOrdinanceCommand
extends Command
## Ends an active ordinance now. Nothing is refunded.

const TYPE: String = "cancel_ordinance"

var ordinance_id: String = ""


static func create(p_empire_id: String, p_ordinance_id: String) -> CancelOrdinanceCommand:
	var c: CancelOrdinanceCommand = CancelOrdinanceCommand.new()
	c.empire_id = p_empire_id
	c.ordinance_id = p_ordinance_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Ordinances.can_cancel(state, empire_id, ordinance_id)


func apply(state: GameState) -> void:
	Ordinances.cancel(state.empires[empire_id], ordinance_id)


func _payload() -> Dictionary:
	return {"ordinance_id": ordinance_id}


func _load_payload(d: Dictionary) -> void:
	ordinance_id = DictIO.str_of(d, "ordinance_id")
