class_name Colony
extends RefCounted
## A settled planet (or an outpost, which is a colony with no pops).

const DEFAULT_JOB_PRIORITY: Array[String] = ["food", "energy", "minerals", "alloys", "research", "clerks"]


## A district placed on one hex slot.
class PlacedDistrict:
	extends RefCounted
	var slot: int = 0
	var district_id: String = ""
	var tier: int = 1

	func to_dict() -> Dictionary:
		return {"slot": slot, "district_id": district_id, "tier": tier}

	static func from_dict(d: Dictionary) -> PlacedDistrict:
		var p: PlacedDistrict = PlacedDistrict.new()
		p.slot = DictIO.int_of(d, "slot")
		p.district_id = DictIO.str_of(d, "district_id")
		p.tier = DictIO.int_of(d, "tier", 1)
		return p


## A building placed on one hex slot.
class PlacedBuilding:
	extends RefCounted
	var slot: int = 0
	var building_id: String = ""

	func to_dict() -> Dictionary:
		return {"slot": slot, "building_id": building_id}

	static func from_dict(d: Dictionary) -> PlacedBuilding:
		var p: PlacedBuilding = PlacedBuilding.new()
		p.slot = DictIO.int_of(d, "slot")
		p.building_id = DictIO.str_of(d, "building_id")
		return p


var id: String = ""
var planet_id: String = ""
var owner_id: String = ""
## Player-chosen name. Empty means "use the planet's name".
var name: String = ""
var pops: int = 0
## Growth progress in centi-units; a new pop arrives at 100.00 (10000).
var growth: int = 0
var stability: int = 50
var districts: Array[PlacedDistrict] = []
var buildings: Array[PlacedBuilding] = []
var job_priority: Array[String] = DEFAULT_JOB_PRIORITY.duplicate()


func district_at(slot: int) -> PlacedDistrict:
	for pd: PlacedDistrict in districts:
		if pd.slot == slot:
			return pd
	return null


func to_dict() -> Dictionary:
	var ds: Array = []
	for pd: PlacedDistrict in districts:
		ds.append(pd.to_dict())
	var bs: Array = []
	for pb: PlacedBuilding in buildings:
		bs.append(pb.to_dict())
	return {
		"id": id, "planet_id": planet_id, "owner_id": owner_id, "name": name, "pops": pops,
		"growth": growth, "stability": stability, "districts": ds, "buildings": bs,
		"job_priority": job_priority.duplicate(),
	}


static func from_dict(d: Dictionary) -> Colony:
	var c: Colony = Colony.new()
	c.id = DictIO.str_of(d, "id")
	c.planet_id = DictIO.str_of(d, "planet_id")
	c.owner_id = DictIO.str_of(d, "owner_id")
	c.name = DictIO.str_of(d, "name")
	c.pops = DictIO.int_of(d, "pops")
	c.growth = DictIO.int_of(d, "growth")
	c.stability = DictIO.int_of(d, "stability", 50)
	for v: Variant in DictIO.arr_of(d, "districts"):
		c.districts.append(PlacedDistrict.from_dict(v))
	for v: Variant in DictIO.arr_of(d, "buildings"):
		c.buildings.append(PlacedBuilding.from_dict(v))
	if d.has("job_priority"):
		c.job_priority = DictIO.str_arr(d, "job_priority")
	return c
