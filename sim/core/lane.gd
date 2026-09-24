class_name Lane
extends RefCounted
## A connection between two systems. Deep lanes are sublight routes; beacon lanes are usable only
## while the beacons at both ends are active.

const KIND_DEEP: String = "deep"
const KIND_BEACON: String = "beacon"

var id: String = ""
var a: String = ""
var b: String = ""
## Length in centi-light-years (1.00 ly = 100).
var length_cly: int = 100
var kind: String = KIND_DEEP


func other_end(system_id: String) -> String:
	return b if system_id == a else a


func to_dict() -> Dictionary:
	return {"id": id, "a": a, "b": b, "length_cly": length_cly, "kind": kind}


static func from_dict(d: Dictionary) -> Lane:
	var l: Lane = Lane.new()
	l.id = DictIO.str_of(d, "id")
	l.a = DictIO.str_of(d, "a")
	l.b = DictIO.str_of(d, "b")
	l.length_cly = DictIO.int_of(d, "length_cly", 100)
	l.kind = DictIO.str_of(d, "kind", KIND_DEEP)
	return l
