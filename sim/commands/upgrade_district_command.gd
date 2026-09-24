class_name UpgradeDistrictCommand
extends Command
## Queues the next tier of a district (§5.4): tier II at the Colony stage with Advanced
## Districts, tier III at the City stage with its tech.

const TYPE: String = "upgrade_district"

var colony_id: String = ""
var slot: int = -1


static func create(p_empire_id: String, p_colony_id: String, p_slot: int) -> UpgradeDistrictCommand:
	var c: UpgradeDistrictCommand = UpgradeDistrictCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.slot = p_slot
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Construction.can_upgrade(state, empire_id, colony_id, slot)


func apply(state: GameState) -> void:
	var c: Colony = state.colonies[colony_id]
	var pd: Colony.PlacedDistrict = c.district_at(slot)
	var tier: int = pd.tier + 1
	Construction.enqueue(state, c, BuildItem.KIND_UPGRADE, pd.district_id, slot, tier, pd.branch, Construction.upgrade_cost(pd.district_id, tier))


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "slot": slot}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	slot = DictIO.int_of(d, "slot", -1)
