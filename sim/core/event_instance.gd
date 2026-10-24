class_name EventInstance
extends RefCounted
## One step of an event chain that has fired and waits for the player's choice, or that is
## scheduled to fire on a later turn (a chain continuation or a delayed scripted step).

var id: String = ""
## Chain id (data/events/<chain>.json).
var chain: String = ""
var step: int = 1
## The colony the event is about, or "" for the empire.
var colony_id: String = ""
var empire_id: String = ""
## Scheduled: the turn it fires. Pending: the turn it fired.
var turn: int = 0
## Why it fired: "scripted", "director", "chain" or "status" (famine, unrest, autonomy).
var cause: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id, "chain": chain, "step": step, "colony_id": colony_id, "empire_id": empire_id,
		"turn": turn, "cause": cause,
	}


static func from_dict(d: Dictionary) -> EventInstance:
	var e: EventInstance = EventInstance.new()
	e.id = DictIO.str_of(d, "id")
	e.chain = DictIO.str_of(d, "chain")
	e.step = DictIO.int_of(d, "step", 1)
	e.colony_id = DictIO.str_of(d, "colony_id")
	e.empire_id = DictIO.str_of(d, "empire_id")
	e.turn = DictIO.int_of(d, "turn")
	e.cause = DictIO.str_of(d, "cause")
	return e
