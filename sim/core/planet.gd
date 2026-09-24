class_name Planet
extends RefCounted
## A planet, gas giant or asteroid belt in a system. Slot counts are derived from size and type
## by the rules; only the blocked slots are state.

var id: String = ""
var system_id: String = ""
var name_key: String = ""
## Planet type id from data/planet_types.json.
var type: String = ""
## Size id ("tiny" .. "huge"); empty for gas giants and belts.
var size: String = ""
var orbit: int = 0
var traits: Array[String] = []
var blocked_slots: Array[int] = []
var colony_id: String = ""
## Seed for the procedural look only; never read by the rules.
var art_seed: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id, "system_id": system_id, "name_key": name_key, "type": type, "size": size,
		"orbit": orbit, "traits": traits.duplicate(), "blocked_slots": blocked_slots.duplicate(),
		"colony_id": colony_id, "art_seed": art_seed,
	}


static func from_dict(d: Dictionary) -> Planet:
	var p: Planet = Planet.new()
	p.id = DictIO.str_of(d, "id")
	p.system_id = DictIO.str_of(d, "system_id")
	p.name_key = DictIO.str_of(d, "name_key")
	p.type = DictIO.str_of(d, "type")
	p.size = DictIO.str_of(d, "size")
	p.orbit = DictIO.int_of(d, "orbit")
	p.traits = DictIO.str_arr(d, "traits")
	p.blocked_slots = DictIO.int_arr(d, "blocked_slots")
	p.colony_id = DictIO.str_of(d, "colony_id")
	p.art_seed = DictIO.int_of(d, "art_seed")
	return p
