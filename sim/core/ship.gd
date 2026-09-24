class_name Ship
extends RefCounted
## One ship. Combat values are in centi-units.

var id: String = ""
var design_id: String = ""
var owner_id: String = ""
var fleet_id: String = ""
var structure: int = 0
var armor: int = 0
var shield: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id, "design_id": design_id, "owner_id": owner_id, "fleet_id": fleet_id,
		"structure": structure, "armor": armor, "shield": shield,
	}


static func from_dict(d: Dictionary) -> Ship:
	var s: Ship = Ship.new()
	s.id = DictIO.str_of(d, "id")
	s.design_id = DictIO.str_of(d, "design_id")
	s.owner_id = DictIO.str_of(d, "owner_id")
	s.fleet_id = DictIO.str_of(d, "fleet_id")
	s.structure = DictIO.int_of(d, "structure")
	s.armor = DictIO.int_of(d, "armor")
	s.shield = DictIO.int_of(d, "shield")
	return s
