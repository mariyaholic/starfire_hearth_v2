class_name BuildOutpostCommand
extends Command
## Orders a Construction Ship to build an outpost on a surveyed gas giant or asteroid belt
## (DESIGN_LOG 60). The influence is paid now.

const TYPE: String = "build_outpost"

var ship_id: String = ""
var planet_id: String = ""
## "minerals" on a belt; "energy" or "research" on a gas giant.
var kind: String = ""


static func create(p_empire_id: String, p_ship_id: String, p_planet_id: String, p_kind: String) -> BuildOutpostCommand:
	var c: BuildOutpostCommand = BuildOutpostCommand.new()
	c.empire_id = p_empire_id
	c.ship_id = p_ship_id
	c.planet_id = p_planet_id
	c.kind = p_kind
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Ships.can_build_outpost(state, empire_id, ship_id, planet_id, kind)


func apply(state: GameState) -> void:
	Ships.start_outpost(state, ship_id, planet_id, kind)


func _payload() -> Dictionary:
	return {"ship_id": ship_id, "planet_id": planet_id, "kind": kind}


func _load_payload(d: Dictionary) -> void:
	ship_id = DictIO.str_of(d, "ship_id")
	planet_id = DictIO.str_of(d, "planet_id")
	kind = DictIO.str_of(d, "kind")
