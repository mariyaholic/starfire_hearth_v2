class_name VetoPlanCommand
extends Command
## Blocks a governor's planned build for 10 turns (§5.4). The plan is named by its key, such as
## "district:agriculture".

const TYPE: String = "veto_plan"

var colony_id: String = ""
var plan_key: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_plan_key: String) -> VetoPlanCommand:
	var c: VetoPlanCommand = VetoPlanCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.plan_key = p_plan_key
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	var failures: Array[Result] = []
	var c: Colony = Command.owned_colony(state, empire_id, colony_id, failures)
	if c == null:
		return failures[0]
	var parts: PackedStringArray = plan_key.split(":")
	if parts.size() != 2 or not [BuildItem.KIND_DISTRICT, BuildItem.KIND_UPGRADE, BuildItem.KIND_BUILDING].has(parts[0]):
		return Result.fail("error.governor.bad_plan")
	if Governor.is_vetoed(state, c, plan_key):
		return Result.fail("error.governor.already_vetoed")
	return Result.success()


func apply(state: GameState) -> void:
	state.colonies[colony_id].governor_vetoes[plan_key] = state.turn + Governor.VETO_TURNS - 1


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "plan_key": plan_key}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	plan_key = DictIO.str_of(d, "plan_key")
