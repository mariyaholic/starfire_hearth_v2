class_name ColonyRules
extends RefCounted
## Facts about planets and colonies that several rules share: slots, habitability, stages and
## building limits (§5.4, DESIGN_LOG 56).

const STAGE_OUTPOST: String = "outpost"
const STAGE_SETTLEMENT: String = "settlement"
const STAGE_COLONY: String = "colony"
const STAGE_CITY: String = "city"
const COLONY_AT: int = 5
const CITY_AT: int = 15

## A developed colony, as the scenario objectives count it (§5.4).
const DEVELOPED_POPS: int = 5
const DEVELOPED_DISTRICTS: int = 6

const BUILDING_CAP: int = 4
const CITY_EXTRA_BUILDINGS: int = 1

const HAB_OPEN: String = "open"
const HAB_DOMES: String = "domes"
const HAB_ORBITAL: String = "orbital"
const HAB_OUTPOST: String = "outpost"


static func stage(colony: Colony) -> String:
	if colony.is_outpost() or colony.pops <= 0:
		return STAGE_OUTPOST
	if colony.pops >= CITY_AT:
		return STAGE_CITY
	if colony.pops >= COLONY_AT:
		return STAGE_COLONY
	return STAGE_SETTLEMENT


## The colony stage a district tier needs: tier II at Colony, tier III at City.
static func stage_for_tier(tier: int) -> String:
	if tier >= 3:
		return STAGE_CITY
	if tier == 2:
		return STAGE_COLONY
	return STAGE_SETTLEMENT


static func stage_reached(colony: Colony, needed: String) -> bool:
	var order: Array[String] = [STAGE_OUTPOST, STAGE_SETTLEMENT, STAGE_COLONY, STAGE_CITY]
	return order.find(stage(colony)) >= order.find(needed)


static func habitability(planet: Planet) -> String:
	return DictIO.str_of(Content.db().record("planet_types", planet.type), "habitability", HAB_OUTPOST)


static func habitability_bp(planet: Planet) -> int:
	return DictIO.int_of(Content.db().record("planet_types", planet.type), "habitability_bp")


static func is_dome_world(planet: Planet) -> bool:
	return habitability(planet) == HAB_DOMES


## Settlers can live here (open worlds always; dome worlds with Habitat Domes).
static func is_settleable(planet: Planet, empire: Empire) -> bool:
	var h: String = habitability(planet)
	if h == HAB_OPEN:
		return true
	return h == HAB_DOMES and empire != null and empire.has_tech("habitat_domes")


## What an outpost here would yield: "minerals" for belts; "energy" or "research" for gas giants.
static func outpost_kinds(planet: Planet) -> Array[String]:
	match habitability(planet):
		HAB_OUTPOST:
			return ["minerals"]
		HAB_ORBITAL:
			return ["energy", "research"]
	return []


## Hex slots on the planet: the size's count, adjusted by traits; dome worlds have half.
static func slot_count(planet: Planet) -> int:
	if planet.size.is_empty():
		return 0
	var n: int = DictIO.int_of(Content.db().record("planet_sizes", planet.size), "slots")
	for trait_id: String in planet.traits:
		for fx: Variant in DictIO.arr_of(Content.db().record("traits", trait_id), "effects"):
			if typeof(fx) == TYPE_DICTIONARY and DictIO.str_of(fx, "key") == "slots_add":
				n += DictIO.int_of(fx, "value")
	if is_dome_world(planet):
		n = Fx.div_floor(n, 2)
	return maxi(0, n)


## Slots with nothing on them, not blocked and not reserved by the build queue, in slot order.
static func free_slots(colony: Colony, planet: Planet) -> Array[int]:
	var out: Array[int] = []
	for slot in slot_count(planet):
		if is_slot_free(colony, planet, slot):
			out.append(slot)
	return out


static func is_slot_free(colony: Colony, planet: Planet, slot: int) -> bool:
	if slot < 0 or slot >= slot_count(planet):
		return false
	if planet.blocked_slots.has(slot):
		return false
	if colony != null:
		if colony.district_at(slot) != null or colony.building_at(slot) != null:
			return false
		if colony.queued_at(slot) != null:
			return false
	return true


## Buildings counted against the limit: placed and queued, landmarks excluded.
static func building_count(colony: Colony) -> int:
	var n: int = 0
	for pb: Colony.PlacedBuilding in colony.buildings:
		if pb.slot != Colony.LANDMARK_SLOT:
			n += 1
	for item: BuildItem in colony.queue:
		if item.kind == BuildItem.KIND_BUILDING:
			n += 1
	return n


static func building_cap(colony: Colony) -> int:
	return BUILDING_CAP + (CITY_EXTRA_BUILDINGS if stage(colony) == STAGE_CITY else 0)


static func is_developed(colony: Colony) -> bool:
	return not colony.is_outpost() and colony.pops >= DEVELOPED_POPS and colony.districts.size() >= DEVELOPED_DISTRICTS


## Owned colonies with settlers (outposts excluded), in id order.
static func settled(state: GameState, empire_id: String) -> Array[Colony]:
	var out: Array[Colony] = []
	for c: Colony in state.colonies_of(empire_id):
		if not c.is_outpost():
			out.append(c)
	return out


static func outposts(state: GameState, empire_id: String) -> Array[Colony]:
	var out: Array[Colony] = []
	for c: Colony in state.colonies_of(empire_id):
		if c.is_outpost():
			out.append(c)
	return out


## String arguments naming a colony: its player-given name, or its planet's name key.
static func name_args(state: GameState, colony: Colony, arg: String = "colony") -> Dictionary:
	if not colony.name.is_empty():
		return {arg: colony.name}
	var planet: Planet = state.planets.get(colony.planet_id, null)
	return {arg + "_key": planet.name_key if planet != null else ""}


## Arguments naming a planet.
static func planet_args(planet: Planet, arg: String = "planet") -> Dictionary:
	return {arg + "_key": planet.name_key}
