class_name StarSystem
extends RefCounted
## A star system on the galaxy map.

const SPECTRAL_CLASSES: Array[String] = ["M", "K", "G", "F", "A", "white_dwarf", "binary"]
const BEACON_NONE: String = "none"
const BEACON_DORMANT: String = "dormant"
const BEACON_ACTIVE: String = "active"

var id: String = ""
var name_key: String = ""
## Map position in centi-light-years.
var x: int = 0
var y: int = 0
var spectral: String = "G"
## 1 (dim) to 5 (bright); sets the drawn size of the star.
var magnitude: int = 3
var planet_ids: Array[String] = []
var specials: Array[String] = []
var beacon: String = BEACON_NONE
var owner_id: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id, "name_key": name_key, "x": x, "y": y, "spectral": spectral,
		"magnitude": magnitude, "planet_ids": planet_ids.duplicate(),
		"specials": specials.duplicate(), "beacon": beacon, "owner_id": owner_id,
	}


static func from_dict(d: Dictionary) -> StarSystem:
	var s: StarSystem = StarSystem.new()
	s.id = DictIO.str_of(d, "id")
	s.name_key = DictIO.str_of(d, "name_key")
	s.x = DictIO.int_of(d, "x")
	s.y = DictIO.int_of(d, "y")
	s.spectral = DictIO.str_of(d, "spectral", "G")
	s.magnitude = DictIO.int_of(d, "magnitude", 3)
	s.planet_ids = DictIO.str_arr(d, "planet_ids")
	s.specials = DictIO.str_arr(d, "specials")
	s.beacon = DictIO.str_of(d, "beacon", BEACON_NONE)
	s.owner_id = DictIO.str_of(d, "owner_id")
	return s
