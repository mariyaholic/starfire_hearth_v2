class_name SurveyCommand
extends Command
## Sends a Survey Probe to survey a planet in its system (DESIGN_LOG 59): 2 turns, then the
## planet's traits and slots are known and it can be settled or used for an outpost.

const TYPE: String = "survey"

var ship_id: String = ""
var planet_id: String = ""


static func create(p_empire_id: String, p_ship_id: String, p_planet_id: String) -> SurveyCommand:
	var c: SurveyCommand = SurveyCommand.new()
	c.empire_id = p_empire_id
	c.ship_id = p_ship_id
	c.planet_id = p_planet_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Ships.can_survey(state, empire_id, ship_id, planet_id)


func apply(state: GameState) -> void:
	Ships.start_survey(state, ship_id, planet_id)


func _payload() -> Dictionary:
	return {"ship_id": ship_id, "planet_id": planet_id}


func _load_payload(d: Dictionary) -> void:
	ship_id = DictIO.str_of(d, "ship_id")
	planet_id = DictIO.str_of(d, "planet_id")
