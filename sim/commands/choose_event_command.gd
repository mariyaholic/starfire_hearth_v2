class_name ChooseEventCommand
extends Command
## Answers a pending event with one of its choices (§5.10). The choice's cost is paid and its
## effects apply at once; "Uncertain" choices roll their outcome on the EVENTS stream.

const TYPE: String = "choose_event"

var event_id: String = ""
var choice: int = 0


static func create(p_empire_id: String, p_event_id: String, p_choice: int) -> ChooseEventCommand:
	var c: ChooseEventCommand = ChooseEventCommand.new()
	c.empire_id = p_empire_id
	c.event_id = p_event_id
	c.choice = p_choice
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Events.can_choose(state, empire_id, event_id, choice)


func apply(state: GameState) -> void:
	Events.choose(state, empire_id, event_id, choice, null)


func _payload() -> Dictionary:
	return {"event_id": event_id, "choice": choice}


func _load_payload(d: Dictionary) -> void:
	event_id = DictIO.str_of(d, "event_id")
	choice = DictIO.int_of(d, "choice")
