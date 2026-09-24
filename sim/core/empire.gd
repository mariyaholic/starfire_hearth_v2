class_name Empire
extends RefCounted
## One empire: the player, an AI power, or the Unlit.

const FOG_SURVEYED: String = "surveyed"
const BRANCHES: Array[String] = ["physics", "society", "engineering"]

var id: String = ""
## Faction id from data/factions.json.
var faction_id: String = ""
## Origin id from data/origins.json (player empires only).
var origin_id: String = ""
var is_player: bool = false
var name_key: String = ""
## The capital colony: it produces the base research (DESIGN_LOG 55), and losing it loses the game.
var capital_id: String = ""
## Resource stocks in centi-units, keyed by resource id. Research is not stocked (see research).
var stock: Dictionary[String, int] = {}
var techs: Array[String] = []
## Tech id -> the turn it was researched.
var tech_turns: Dictionary[String, int] = {}
## Branch id -> hand, card and stored progress.
var research: Dictionary[String, ResearchBranch] = {}
## Active ordinances: id -> turns left (-1: until cancelled).
var ordinances: Dictionary[String, int] = {}
## Planets this empire has surveyed (traits and slots known; DESIGN_LOG 59).
var surveyed_planets: Array[String] = []
## Progress toward the next Sealed Order fragment, in centi-units (10.00 per fragment).
var decode_progress: int = 0
## Legacies carried from earlier scenarios.
var legacies: Array[String] = []
## Consecutive turns the energy grid has been short (DESIGN_LOG 54); 0 when it is not.
var energy_short_turns: int = 0
## Noise meter in centi-units (0.00 to 100.00).
var noise: int = 0
## Fog memory: system id -> FOG_SURVEYED. Absent means unknown. "Observed" is computed each turn
## from sensor range and is not stored.
var known_systems: Dictionary[String, String] = {}
var flags: Dictionary[String, int] = {}


func stock_of(resource_id: String) -> int:
	return stock.get(resource_id, 0)


func has_tech(tech_id: String) -> bool:
	return techs.has(tech_id)


func branch(branch_id: String) -> ResearchBranch:
	if not research.has(branch_id):
		var r: ResearchBranch = ResearchBranch.new()
		r.branch = branch_id
		research[branch_id] = r
	return research[branch_id]


func to_dict() -> Dictionary:
	var rs: Dictionary = {}
	for b: String in DictIO.sorted_keys(research):
		rs[b] = research[b].to_dict()
	return {
		"id": id, "faction_id": faction_id, "origin_id": origin_id, "is_player": is_player,
		"name_key": name_key, "capital_id": capital_id, "stock": DictIO.plain(stock),
		"techs": techs.duplicate(), "tech_turns": DictIO.plain(tech_turns), "research": rs,
		"ordinances": DictIO.plain(ordinances), "surveyed_planets": surveyed_planets.duplicate(),
		"decode_progress": decode_progress, "legacies": legacies.duplicate(),
		"energy_short_turns": energy_short_turns, "noise": noise,
		"known_systems": DictIO.plain(known_systems), "flags": DictIO.plain(flags),
	}


static func from_dict(d: Dictionary) -> Empire:
	var e: Empire = Empire.new()
	e.id = DictIO.str_of(d, "id")
	e.faction_id = DictIO.str_of(d, "faction_id")
	e.origin_id = DictIO.str_of(d, "origin_id")
	e.is_player = DictIO.bool_of(d, "is_player")
	e.name_key = DictIO.str_of(d, "name_key")
	e.capital_id = DictIO.str_of(d, "capital_id")
	e.stock = DictIO.int_map(d, "stock")
	e.techs = DictIO.str_arr(d, "techs")
	e.tech_turns = DictIO.int_map(d, "tech_turns")
	var rs: Dictionary = DictIO.dict_of(d, "research")
	for b: String in DictIO.sorted_keys(rs):
		e.research[b] = ResearchBranch.from_dict(rs[b])
	e.ordinances = DictIO.int_map(d, "ordinances")
	e.surveyed_planets = DictIO.str_arr(d, "surveyed_planets")
	e.decode_progress = DictIO.int_of(d, "decode_progress")
	e.legacies = DictIO.str_arr(d, "legacies")
	e.energy_short_turns = DictIO.int_of(d, "energy_short_turns")
	e.noise = DictIO.int_of(d, "noise")
	e.known_systems = DictIO.str_map(d, "known_systems")
	e.flags = DictIO.int_map(d, "flags")
	return e
