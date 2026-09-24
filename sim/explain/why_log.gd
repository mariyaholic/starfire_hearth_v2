class_name WhyLog
extends RefCounted
## Causal records for the Why? inspector: for a selection, what changed this turn and what caused
## it ("Stability fell 58 -> 44: +2 unemployed (-6), Festival expired (-10), ...").
## Also carries AI decisions (with their top considerations), event trigger reasons and combat
## factors, all as text keys and arguments.

const KIND_CHANGE: String = "change"
const KIND_AI_ACTION: String = "ai_action"
const KIND_EVENT_TRIGGER: String = "event_trigger"
const KIND_COMBAT: String = "combat"


## One cause of an entry.
class Cause:
	extends RefCounted
	var source_key: String = ""
	var source_args: Dictionary = {}
	var value: int = 0

	func to_dict() -> Dictionary:
		return {"source_key": source_key, "source_args": source_args.duplicate(true), "value": value}


class Entry:
	extends RefCounted
	var kind: String = KIND_CHANGE
	var turn: int = 0
	var subject_kind: String = ""
	var subject_id: String = ""
	var label_key: String = ""
	var label_args: Dictionary = {}
	var unit: String = Breakdown.UNIT_POINTS
	var from_value: int = 0
	var to_value: int = 0
	var causes: Array[Cause] = []

	func to_dict() -> Dictionary:
		var cs: Array = []
		for c: Cause in causes:
			cs.append(c.to_dict())
		return {
			"kind": kind, "turn": turn, "subject_kind": subject_kind, "subject_id": subject_id,
			"label_key": label_key, "label_args": label_args.duplicate(true), "unit": unit,
			"from_value": from_value, "to_value": to_value, "causes": cs,
		}


var entries: Array[Entry] = []


## Records a change and returns the entry so callers can add causes with cause().
func record(kind: String, turn: int, subject_kind: String, subject_id: String, label_key: String, from_value: int = 0, to_value: int = 0, unit: String = Breakdown.UNIT_POINTS, label_args: Dictionary = {}) -> Entry:
	var e: Entry = Entry.new()
	e.kind = kind
	e.turn = turn
	e.subject_kind = subject_kind
	e.subject_id = subject_id
	e.label_key = label_key
	e.label_args = label_args
	e.from_value = from_value
	e.to_value = to_value
	e.unit = unit
	entries.append(e)
	return e


static func cause(entry: Entry, source_key: String, value: int, source_args: Dictionary = {}) -> void:
	var c: Cause = Cause.new()
	c.source_key = source_key
	c.value = value
	c.source_args = source_args
	entry.causes.append(c)


func for_subject(subject_kind: String, subject_id: String) -> Array[Entry]:
	var out: Array[Entry] = []
	for e: Entry in entries:
		if e.subject_kind == subject_kind and e.subject_id == subject_id:
			out.append(e)
	return out


func to_array() -> Array:
	var out: Array = []
	for e: Entry in entries:
		out.append(e.to_dict())
	return out
