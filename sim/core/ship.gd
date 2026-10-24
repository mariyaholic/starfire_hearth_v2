class_name Ship
extends RefCounted
## One ship. Civilian ships name their hull directly; warships (M2) use a design. Combat values
## are in centi-units.

const TASK_NONE: String = ""
const TASK_SURVEY: String = "survey"
const TASK_OUTPOST: String = "outpost"
const TASK_COLONISE: String = "colonise"

var id: String = ""
var design_id: String = ""
## Hull id for civilian ships (survey_probe, construction_ship, colony_ship).
var hull: String = ""
var owner_id: String = ""
var fleet_id: String = ""
var structure: int = 0
var armor: int = 0
var shield: int = 0
## The civilian task in progress, its target planet, a parameter (the outpost's resource) and
## the turns it still needs.
var task: String = TASK_NONE
var task_target: String = ""
var task_param: String = ""
var task_turns: int = 0


func is_busy() -> bool:
	return task != TASK_NONE


func to_dict() -> Dictionary:
	return {
		"id": id, "design_id": design_id, "hull": hull, "owner_id": owner_id,
		"fleet_id": fleet_id, "structure": structure, "armor": armor, "shield": shield,
		"task": task, "task_target": task_target, "task_param": task_param,
		"task_turns": task_turns,
	}


static func from_dict(d: Dictionary) -> Ship:
	var s: Ship = Ship.new()
	s.id = DictIO.str_of(d, "id")
	s.design_id = DictIO.str_of(d, "design_id")
	s.hull = DictIO.str_of(d, "hull")
	s.owner_id = DictIO.str_of(d, "owner_id")
	s.fleet_id = DictIO.str_of(d, "fleet_id")
	s.structure = DictIO.int_of(d, "structure")
	s.armor = DictIO.int_of(d, "armor")
	s.shield = DictIO.int_of(d, "shield")
	s.task = DictIO.str_of(d, "task")
	s.task_target = DictIO.str_of(d, "task_target")
	s.task_param = DictIO.str_of(d, "task_param")
	s.task_turns = DictIO.int_of(d, "task_turns")
	return s
