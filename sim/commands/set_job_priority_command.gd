class_name SetJobPriorityCommand
extends Command
## Reorders which jobs a colony fills first (§5.4). The order must name every job group once.

const TYPE: String = "set_job_priority"

var colony_id: String = ""
var order: Array[String] = []


static func create(p_empire_id: String, p_colony_id: String, p_order: Array[String]) -> SetJobPriorityCommand:
	var c: SetJobPriorityCommand = SetJobPriorityCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.order = p_order.duplicate()
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	var failures: Array[Result] = []
	if Command.owned_colony(state, empire_id, colony_id, failures) == null:
		return failures[0]
	var expected: Array[String] = Colony.DEFAULT_JOB_PRIORITY.duplicate()
	var given: Array[String] = order.duplicate()
	expected.sort()
	given.sort()
	if given != expected:
		return Result.fail("error.job_priority.not_permutation")
	return Result.success()


func apply(state: GameState) -> void:
	state.colonies[colony_id].job_priority = order.duplicate()


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "order": order.duplicate()}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	order = DictIO.str_arr(d, "order")
