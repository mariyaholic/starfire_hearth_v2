class_name RushBuildCommand
extends Command
## Pays energy to take one turn off the build in progress (DESIGN_LOG 81).

const TYPE: String = "rush_build"

var colony_id: String = ""
var item_id: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_item_id: String) -> RushBuildCommand:
	var c: RushBuildCommand = RushBuildCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.item_id = p_item_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_rush(state, empire_id, colony_id, item_id)


func apply(state: GameState) -> void:
	Construction.rush(state, state.colonies[colony_id], item_id)


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "item_id": item_id}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	item_id = DictIO.str_of(d, "item_id")
