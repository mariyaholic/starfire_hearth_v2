class_name RenameColonyCommand
extends Command
## Gives a colony a player-chosen name. An empty name restores the planet's own name.

const TYPE: String = "rename_colony"
const MAX_LENGTH: int = 24

var colony_id: String = ""
var new_name: String = ""


static func create(p_empire_id: String, p_colony_id: String, p_new_name: String) -> RenameColonyCommand:
	var c: RenameColonyCommand = RenameColonyCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.new_name = p_new_name
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	var failures: Array[Result] = []
	if Command.owned_colony(state, empire_id, colony_id, failures) == null:
		return failures[0]
	var clean: String = new_name.strip_edges()
	if clean.length() > MAX_LENGTH:
		return Result.fail("error.name.too_long", {"max": MAX_LENGTH})
	for i in clean.length():
		if clean.unicode_at(i) < 0x20:
			return Result.fail("error.name.invalid_chars")
	return Result.success()


func apply(state: GameState) -> void:
	state.colonies[colony_id].name = new_name.strip_edges()


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "new_name": new_name}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	new_name = DictIO.str_of(d, "new_name")
