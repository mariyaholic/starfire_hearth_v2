class_name BuildBuildingCommand
extends Command
## Queues a building on a free hex slot (§10.3).

const TYPE: String = "build_building"

var colony_id: String = ""
var slot: int = -1
var building_id: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_slot: int, p_building_id: String) -> BuildBuildingCommand:
	var c: BuildBuildingCommand = BuildBuildingCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.slot = p_slot
	c.building_id = p_building_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_build_building(state, empire_id, colony_id, slot, building_id)


func apply(state: GameState) -> void:
	var c: Colony = state.colonies[colony_id]
	Construction.enqueue(state, c, BuildItem.KIND_BUILDING, building_id, slot, 1, "", Construction.building_cost(building_id))


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "slot": slot, "building_id": building_id}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	slot = DictIO.int_of(d, "slot", -1)
	building_id = DictIO.str_of(d, "building_id")
