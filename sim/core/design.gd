class_name Design
extends RefCounted
## A ship design: a hull plus one module id per slot ("" for an empty slot).

var id: String = ""
var owner_id: String = ""
## Player-chosen name, or empty to use name_key.
var name: String = ""
var name_key: String = ""
var hull: String = ""
var modules: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"id": id, "owner_id": owner_id, "name": name, "name_key": name_key, "hull": hull,
		"modules": modules.duplicate(),
	}


static func from_dict(d: Dictionary) -> Design:
	var ds: Design = Design.new()
	ds.id = DictIO.str_of(d, "id")
	ds.owner_id = DictIO.str_of(d, "owner_id")
	ds.name = DictIO.str_of(d, "name")
	ds.name_key = DictIO.str_of(d, "name_key")
	ds.hull = DictIO.str_of(d, "hull")
	ds.modules = DictIO.str_arr(d, "modules")
	return ds
