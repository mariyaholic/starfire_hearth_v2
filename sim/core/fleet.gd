class_name Fleet
extends RefCounted
## A group of ships that moves and fights together.

const STANCES: Array[String] = ["cautious", "balanced", "aggressive", "last_stand"]

var id: String = ""
var owner_id: String = ""
var system_id: String = ""
var ship_ids: Array[String] = []
var stance: String = "balanced"
## Remaining route, next system first.
var path: Array[String] = []
## Turns already spent on the current lane.
var move_progress: int = 0
var admiral_id: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id, "owner_id": owner_id, "system_id": system_id, "ship_ids": ship_ids.duplicate(),
		"stance": stance, "path": path.duplicate(), "move_progress": move_progress,
		"admiral_id": admiral_id,
	}


static func from_dict(d: Dictionary) -> Fleet:
	var f: Fleet = Fleet.new()
	f.id = DictIO.str_of(d, "id")
	f.owner_id = DictIO.str_of(d, "owner_id")
	f.system_id = DictIO.str_of(d, "system_id")
	f.ship_ids = DictIO.str_arr(d, "ship_ids")
	f.stance = DictIO.str_of(d, "stance", "balanced")
	f.path = DictIO.str_arr(d, "path")
	f.move_progress = DictIO.int_of(d, "move_progress")
	f.admiral_id = DictIO.str_of(d, "admiral_id")
	return f
