class_name Empire
extends RefCounted
## One empire: the player, an AI power, or the Unlit.

const FOG_SURVEYED: String = "surveyed"

var id: String = ""
## Faction id from data/factions.json.
var faction_id: String = ""
## Origin id from data/origins.json (player empires only).
var origin_id: String = ""
var is_player: bool = false
var name_key: String = ""
## Resource stocks in centi-units, keyed by resource id.
var stock: Dictionary[String, int] = {}
var techs: Array[String] = []
## Noise meter in centi-units (0.00 to 100.00).
var noise: int = 0
## Fog memory: system id -> FOG_SURVEYED. Absent means unknown. "Observed" is computed each turn
## from sensor range and is not stored.
var known_systems: Dictionary[String, String] = {}
var flags: Dictionary[String, int] = {}


func stock_of(resource_id: String) -> int:
	return stock.get(resource_id, 0)


func to_dict() -> Dictionary:
	return {
		"id": id, "faction_id": faction_id, "origin_id": origin_id, "is_player": is_player,
		"name_key": name_key, "stock": DictIO.plain(stock), "techs": techs.duplicate(),
		"noise": noise, "known_systems": DictIO.plain(known_systems), "flags": DictIO.plain(flags),
	}


static func from_dict(d: Dictionary) -> Empire:
	var e: Empire = Empire.new()
	e.id = DictIO.str_of(d, "id")
	e.faction_id = DictIO.str_of(d, "faction_id")
	e.origin_id = DictIO.str_of(d, "origin_id")
	e.is_player = DictIO.bool_of(d, "is_player")
	e.name_key = DictIO.str_of(d, "name_key")
	e.stock = DictIO.int_map(d, "stock")
	e.techs = DictIO.str_arr(d, "techs")
	e.noise = DictIO.int_of(d, "noise")
	e.known_systems = DictIO.str_map(d, "known_systems")
	e.flags = DictIO.int_map(d, "flags")
	return e
