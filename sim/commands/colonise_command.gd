class_name ColoniseCommand
extends Command
## Lands a Colony Ship on a surveyed world: the colony is founded at the end of the turn with 2
## pops and its first shelter.

const TYPE: String = "colonise"

var ship_id: String = ""
var planet_id: String = ""


static func create(p_empire_id: String, p_ship_id: String, p_planet_id: String) -> ColoniseCommand:
	var c: ColoniseCommand = ColoniseCommand.new()
	c.empire_id = p_empire_id
	c.ship_id = p_ship_id
	c.planet_id = p_planet_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Ships.can_colonise(state, empire_id, ship_id, planet_id)


func apply(state: GameState) -> void:
	Ships.start_colonise(state, ship_id, planet_id)


func _payload() -> Dictionary:
	return {"ship_id": ship_id, "planet_id": planet_id}


func _load_payload(d: Dictionary) -> void:
	ship_id = DictIO.str_of(d, "ship_id")
	planet_id = DictIO.str_of(d, "planet_id")
