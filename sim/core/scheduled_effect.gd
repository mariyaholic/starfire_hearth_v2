class_name ScheduledEffect
extends RefCounted
## An effect delivered gradually, such as "+6 pops over 10 turns" from waking the Cold Sleepers.
## Each turn delivers the part that is due, so the total arrives exactly on the last turn.

var id: String = ""
var key: String = ""
var target: String = ""
var value: int = 0
var empire_id: String = ""
var colony_id: String = ""
var over_turns: int = 1
var elapsed: int = 0
var delivered: int = 0
## String-table key naming the cause, for reports and breakdowns.
var source_key: String = ""


## The amount due this turn (call once per turn, then add it to `delivered`).
func due_now() -> int:
	var next_elapsed: int = mini(elapsed + 1, over_turns)
	return Fx.div_floor(value * next_elapsed, maxi(1, over_turns)) - delivered


func to_dict() -> Dictionary:
	return {
		"id": id, "key": key, "target": target, "value": value, "empire_id": empire_id,
		"colony_id": colony_id, "over_turns": over_turns, "elapsed": elapsed,
		"delivered": delivered, "source_key": source_key,
	}


static func from_dict(d: Dictionary) -> ScheduledEffect:
	var s: ScheduledEffect = ScheduledEffect.new()
	s.id = DictIO.str_of(d, "id")
	s.key = DictIO.str_of(d, "key")
	s.target = DictIO.str_of(d, "target")
	s.value = DictIO.int_of(d, "value")
	s.empire_id = DictIO.str_of(d, "empire_id")
	s.colony_id = DictIO.str_of(d, "colony_id")
	s.over_turns = DictIO.int_of(d, "over_turns", 1)
	s.elapsed = DictIO.int_of(d, "elapsed")
	s.delivered = DictIO.int_of(d, "delivered")
	s.source_key = DictIO.str_of(d, "source_key")
	return s
