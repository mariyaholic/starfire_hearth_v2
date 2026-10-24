class_name DemolishCommand
extends Command
## Removes a district or building at once, with no refund (DESIGN_LOG 57).

const TYPE: String = "demolish"

var colony_id: String = ""
var slot: int = -1


static func create(p_empire_id: String, p_colony_id: String, p_slot: int) -> DemolishCommand:
	var c: DemolishCommand = DemolishCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.slot = p_slot
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_demolish(state, empire_id, colony_id, slot)


func apply(state: GameState) -> void:
	Construction.demolish(state.colonies[colony_id], slot)


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "slot": slot}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	slot = DictIO.int_of(d, "slot", -1)
