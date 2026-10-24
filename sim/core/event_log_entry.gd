class_name EventLogEntry
extends RefCounted
## One line of the event log (§5.10): which step fired, when, and what the player chose. Text is
## rebuilt from the event data when the log is read, so the log stays small.

var turn: int = 0
var chain: String = ""
var step: int = 1
var colony_id: String = ""
## Index of the chosen option, -1 while unanswered.
var choice: int = -1
## For an "Uncertain" choice: the index of the outcome that was rolled, else -1.
var outcome: int = -1


func to_dict() -> Dictionary:
	return {
		"turn": turn, "chain": chain, "step": step, "colony_id": colony_id, "choice": choice,
		"outcome": outcome,
	}


static func from_dict(d: Dictionary) -> EventLogEntry:
	var e: EventLogEntry = EventLogEntry.new()
	e.turn = DictIO.int_of(d, "turn")
	e.chain = DictIO.str_of(d, "chain")
	e.step = DictIO.int_of(d, "step", 1)
	e.colony_id = DictIO.str_of(d, "colony_id")
	e.choice = DictIO.int_of(d, "choice", -1)
	e.outcome = DictIO.int_of(d, "outcome", -1)
	return e
