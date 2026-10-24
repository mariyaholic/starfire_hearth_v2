class_name BuildShipCommand
extends Command
## Queues a civilian ship at a colony with a Spaceport (§5.6).

const TYPE: String = "build_ship"

var colony_id: String = ""
var hull_id: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_hull_id: String) -> BuildShipCommand:
	var c: BuildShipCommand = BuildShipCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.hull_id = p_hull_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_build_ship(state, empire_id, colony_id, hull_id)


func apply(state: GameState) -> void:
	var c: Colony = state.colonies[colony_id]
	Construction.enqueue(state, c, BuildItem.KIND_SHIP, hull_id, -1, 1, "", Construction.ship_cost(state, c, hull_id))


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "hull_id": hull_id}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	hull_id = DictIO.str_of(d, "hull_id")
