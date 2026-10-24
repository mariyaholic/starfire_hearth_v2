class_name Colony
extends RefCounted
## A settled planet, or an outpost: a colony with no pops that yields one resource (DESIGN_LOG 60).

const DEFAULT_JOB_PRIORITY: Array[String] = ["food", "energy", "minerals", "alloys", "research", "clerks"]
const GOVERNOR_FOCUSES: Array[String] = ["balanced", "food", "industry", "research", "growth", "stability"]
const DEFAULT_GOVERNOR_BUDGET_BP: int = 5000
## Landmark buildings take no hex slot (DESIGN_LOG 56).
const LANDMARK_SLOT: int = -1


## A district placed on one hex slot.
class PlacedDistrict:
	extends RefCounted
	var slot: int = 0
	var district_id: String = ""
	var tier: int = 1
	## Research districts: the branch their researchers work in (DESIGN_LOG 58).
	var branch: String = ""

	func to_dict() -> Dictionary:
		return {"slot": slot, "district_id": district_id, "tier": tier, "branch": branch}

	static func from_dict(d: Dictionary) -> PlacedDistrict:
		var p: PlacedDistrict = PlacedDistrict.new()
		p.slot = DictIO.int_of(d, "slot")
		p.district_id = DictIO.str_of(d, "district_id")
		p.tier = DictIO.int_of(d, "tier", 1)
		p.branch = DictIO.str_of(d, "branch")
		return p


## A building placed on one hex slot, or a landmark (slot LANDMARK_SLOT).
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
## Last computed stability (0-100). Recomputed every turn from its sources (DESIGN_LOG 73).
var stability: int = 50
var districts: Array[PlacedDistrict] = []
var buildings: Array[PlacedBuilding] = []
var job_priority: Array[String] = DEFAULT_JOB_PRIORITY.duplicate()
var queue: Array[BuildItem] = []
## Outposts: the resource they yield ("minerals", "energy" or "research"); "" for a settled colony.
var outpost_kind: String = ""
var founded_turn: int = 1
var governor_on: bool = false
var governor_focus: String = "balanced"
## Share of the empire's minerals income this colony's governor may spend, in basis points.
var governor_budget_bp: int = DEFAULT_GOVERNOR_BUDGET_BP
## Minerals the governor has saved toward its next build, in centi-units.
var governor_funds: int = 0
## Vetoed plans: plan key -> the last turn the veto holds.
var governor_vetoes: Dictionary[String, int] = {}
## Consecutive famine turns; a pop is lost every third (§5.4).
var famine_turns: int = 0
## Consecutive turns at stability 5 or below; autonomy is declared after the warning (§5.4).
var autonomy_turns: int = 0
## Set when the colony declared autonomy from this empire (its owner is then empty).
var autonomous_from: String = ""


func is_outpost() -> bool:
	return not outpost_kind.is_empty()


func district_at(slot: int) -> PlacedDistrict:
	for pd: PlacedDistrict in districts:
		if pd.slot == slot:
			return pd
	return null


func building_at(slot: int) -> PlacedBuilding:
	if slot == LANDMARK_SLOT:
		return null
	for pb: PlacedBuilding in buildings:
		if pb.slot == slot:
			return pb
	return null


func has_building(building_id: String) -> bool:
	for pb: PlacedBuilding in buildings:
		if pb.building_id == building_id:
			return true
	return false


## The queued item reserving `slot`, or null.
func queued_at(slot: int) -> BuildItem:
	for item: BuildItem in queue:
		if item.slot == slot and item.kind != BuildItem.KIND_SHIP:
			return item
	return null


func to_dict() -> Dictionary:
	var ds: Array = []
	for pd: PlacedDistrict in districts:
		ds.append(pd.to_dict())
	var bs: Array = []
	for pb: PlacedBuilding in buildings:
		bs.append(pb.to_dict())
	var qs: Array = []
	for item: BuildItem in queue:
		qs.append(item.to_dict())
	return {
		"id": id, "planet_id": planet_id, "owner_id": owner_id, "name": name, "pops": pops,
		"growth": growth, "stability": stability, "districts": ds, "buildings": bs,
		"job_priority": job_priority.duplicate(), "queue": qs, "outpost_kind": outpost_kind,
		"founded_turn": founded_turn, "governor_on": governor_on,
		"governor_focus": governor_focus, "governor_budget_bp": governor_budget_bp,
		"governor_funds": governor_funds, "governor_vetoes": DictIO.plain(governor_vetoes),
		"famine_turns": famine_turns, "autonomy_turns": autonomy_turns,
		"autonomous_from": autonomous_from,
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
	for v: Variant in DictIO.arr_of(d, "queue"):
		c.queue.append(BuildItem.from_dict(v))
	c.outpost_kind = DictIO.str_of(d, "outpost_kind")
	c.founded_turn = DictIO.int_of(d, "founded_turn", 1)
	c.governor_on = DictIO.bool_of(d, "governor_on")
	c.governor_focus = DictIO.str_of(d, "governor_focus", "balanced")
	c.governor_budget_bp = DictIO.int_of(d, "governor_budget_bp", DEFAULT_GOVERNOR_BUDGET_BP)
	c.governor_funds = DictIO.int_of(d, "governor_funds")
	c.governor_vetoes = DictIO.int_map(d, "governor_vetoes")
	c.famine_turns = DictIO.int_of(d, "famine_turns")
	c.autonomy_turns = DictIO.int_of(d, "autonomy_turns")
	c.autonomous_from = DictIO.str_of(d, "autonomous_from")
	return c
