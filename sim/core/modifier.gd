class_name Modifier
extends RefCounted
## A lasting effect from an event choice or a story step, such as "Labor Strike: −10 stability for
## 5 turns" or the Founders' Vote's permanent bonus. It applies its effects to one colony, or to
## every colony of its empire when colony_id is empty, and shows as one breakdown line named by
## source_key.

var id: String = ""
## String-table key naming the cause (usually the event's title).
var source_key: String = ""
var empire_id: String = ""
## Empty: the whole empire.
var colony_id: String = ""
## {key, value, target?} records, as in data (EffectKeys).
var effects: Array[Dictionary] = []
## Turns remaining, counting this one; -1 is permanent.
var turns_left: int = -1


func is_permanent() -> bool:
	return turns_left < 0


func to_dict() -> Dictionary:
	var fx: Array = []
	for e: Dictionary in effects:
		fx.append(e.duplicate(true))
	return {
		"id": id, "source_key": source_key, "empire_id": empire_id, "colony_id": colony_id,
		"effects": fx, "turns_left": turns_left,
	}


static func from_dict(d: Dictionary) -> Modifier:
	var m: Modifier = Modifier.new()
	m.id = DictIO.str_of(d, "id")
	m.source_key = DictIO.str_of(d, "source_key")
	m.empire_id = DictIO.str_of(d, "empire_id")
	m.colony_id = DictIO.str_of(d, "colony_id")
	for v: Variant in DictIO.arr_of(d, "effects"):
		if typeof(v) == TYPE_DICTIONARY:
			m.effects.append(v)
	m.turns_left = DictIO.int_of(d, "turns_left", -1)
	return m
