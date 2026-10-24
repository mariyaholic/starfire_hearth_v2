class_name PlaceDistrictCommand
extends Command
## Queues a new district on a free hex slot (§5.4). A Research district names its branch.

const TYPE: String = "place_district"

var colony_id: String = ""
var slot: int = -1
var district_id: String = ""
var branch: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_slot: int, p_district_id: String, p_branch: String = "") -> PlaceDistrictCommand:
	var c: PlaceDistrictCommand = PlaceDistrictCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.slot = p_slot
	c.district_id = p_district_id
	c.branch = p_branch
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_place_district(state, empire_id, colony_id, slot, district_id, branch)


func apply(state: GameState) -> void:
	var c: Colony = state.colonies[colony_id]
	Construction.enqueue(state, c, BuildItem.KIND_DISTRICT, district_id, slot, 1, branch, Construction.district_cost(district_id))


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "slot": slot, "district_id": district_id, "branch": branch}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	slot = DictIO.int_of(d, "slot", -1)
	district_id = DictIO.str_of(d, "district_id")
	branch = DictIO.str_of(d, "branch")
