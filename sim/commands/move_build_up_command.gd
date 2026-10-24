class_name MoveBuildUpCommand
extends Command
## Moves a queued item one place toward the front; the front item is the one being built.

const TYPE: String = "move_build_up"

var colony_id: String = ""
var item_id: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_item_id: String) -> MoveBuildUpCommand:
	var c: MoveBuildUpCommand = MoveBuildUpCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.item_id = p_item_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_move_up(state, empire_id, colony_id, item_id)


func apply(state: GameState) -> void:
	Construction.move_up(state.colonies[colony_id], item_id)


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "item_id": item_id}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	item_id = DictIO.str_of(d, "item_id")
