class_name BuildItem
extends RefCounted
## One entry of a colony's build queue (DESIGN_LOG 57). Only the first entry progresses; the cost
## was paid when it was queued and is refunded in full if it is cancelled.

const KIND_DISTRICT: String = "district"
const KIND_UPGRADE: String = "upgrade"
const KIND_BUILDING: String = "building"
const KIND_SHIP: String = "ship"

var id: String = ""
var kind: String = KIND_DISTRICT
## District, building or hull id.
var def_id: String = ""
## Hex slot for districts, upgrades and buildings; -1 for ships.
var slot: int = -1
## The tier the district will have when this completes.
var tier: int = 1
## Research branch of a Research district.
var branch: String = ""
var turns_left: int = 0
var total_turns: int = 0
## What was paid when it was queued, in centi-units.
var paid: Dictionary[String, int] = {}
## Queued by the colony's governor rather than the player.
var by_governor: bool = false
## The last turn this item was rushed (DESIGN_LOG 81); 0 if never.
var rushed_turn: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id, "kind": kind, "def_id": def_id, "slot": slot, "tier": tier, "branch": branch,
		"turns_left": turns_left, "total_turns": total_turns, "paid": DictIO.plain(paid),
		"by_governor": by_governor, "rushed_turn": rushed_turn,
	}


static func from_dict(d: Dictionary) -> BuildItem:
	var b: BuildItem = BuildItem.new()
	b.id = DictIO.str_of(d, "id")
	b.kind = DictIO.str_of(d, "kind", KIND_DISTRICT)
	b.def_id = DictIO.str_of(d, "def_id")
	b.slot = DictIO.int_of(d, "slot", -1)
	b.tier = DictIO.int_of(d, "tier", 1)
	b.branch = DictIO.str_of(d, "branch")
	b.turns_left = DictIO.int_of(d, "turns_left")
	b.total_turns = DictIO.int_of(d, "total_turns")
	b.paid = DictIO.int_map(d, "paid")
	b.by_governor = DictIO.bool_of(d, "by_governor")
	b.rushed_turn = DictIO.int_of(d, "rushed_turn")
	return b
