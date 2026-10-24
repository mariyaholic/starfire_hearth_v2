class_name AcknowledgeCommand
extends Command
## Records that a tutorial step is done (DESIGN_LOG 62). It changes nothing the rules read; the
## flag keeps the tutorial's place in the save.

const TYPE: String = "acknowledge"
const PREFIX: String = "tut:"

var step_id: String = ""


static func create(p_empire_id: String, p_step_id: String) -> AcknowledgeCommand:
	var c: AcknowledgeCommand = AcknowledgeCommand.new()
	c.empire_id = p_empire_id
	c.step_id = p_step_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	if not state.empires.has(empire_id) or not state.empires[empire_id].is_player:
		return Result.fail("error.empire.not_found")
	if step_id.is_empty() or step_id.length() > 48:
		return Result.fail("error.tutorial.bad_step")
	if state.flags.has(PREFIX + step_id):
		return Result.fail("error.tutorial.already_done")
	return Result.success()


func apply(state: GameState) -> void:
	state.flags[PREFIX + step_id] = state.turn


func _payload() -> Dictionary:
	return {"step_id": step_id}


func _load_payload(d: Dictionary) -> void:
	step_id = DictIO.str_of(d, "step_id")
