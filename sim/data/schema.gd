class_name DataSchema
extends RefCounted
## The shape of every data table (§13.1). Field types:
##   id            unique snake_case id of the record
##   key           string-table key that must exist in strings/en.csv
##   str int bool  plain values
##   centi         resource amount in centi-units ("4.00" strings are converted on load)
##   bp            basis points
##   icon          icon id; the file assets/icons/<id>.svg is checked by tools/validate_data.gd
##   token         colour token name; checked by tools/validate_data.gd
##   hex           "#RRGGBB" colour
##   res_map       {resource id: centi}
##   effects       list of {key, value, target?} with keys from EffectKeys
##   ref:<table>   id of a record in another table
##   enum:a|b|c    one of the listed words
##   list:<type>   list of <type>
##   obj:<name>    nested object described in OBJECTS
## A leading "?" makes a field optional. Unknown fields are errors (they are usually typos).

const TABLES: Dictionary = {
	"resources": {
		"file": "resources.json", "list": "resources",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "color": "token",
			"cap": "?centi", "tradable": "bool", "branches": "?list:str", "sinks": "list:str",
			"unit_key": "?key",
		},
	},
	"jobs": {
		"file": "jobs.json", "list": "jobs",
		"fields": {
			"id": "id", "name_key": "key", "group": "enum:food|energy|minerals|alloys|research|clerks",
			"output": "res_map", "input": "?res_map", "stability_add": "?int",
		},
	},
	"districts": {
		"file": "districts.json", "list": "districts",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "cost": "res_map",
			"build_turns": "int", "upkeep": "res_map", "housing": "int", "jobs": "list:obj:job_slot",
			"adjacency": "list:obj:adjacency", "tiers": "list:obj:tier", "branch_choice": "?bool",
		},
	},
	"planet_types": {
		"file": "planet_types.json", "list": "planet_types",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon",
			"habitability": "enum:open|domes|orbital|outpost", "habitability_bp": "bp",
			"gen_weight": "int", "effects": "effects", "palette": "list:hex",
		},
	},
	"planet_sizes": {
		"file": "planet_sizes.json", "list": "planet_sizes",
		"fields": {"id": "id", "name_key": "key", "slots": "int", "radius": "int"},
	},
	"traits": {
		"file": "traits.json", "list": "traits",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "effects": "effects",
			"domes_only": "?bool", "blocked_slots": "?int",
		},
	},
	"factions": {
		"file": "factions.json", "list": "factions",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "kind": "enum:player|power|pirate",
			"color": "token", "emblem": "icon",
		},
	},
	"origins": {
		"file": "origins.json", "list": "origins",
		"fields": {"id": "id", "name_key": "key", "desc_key": "key", "modes": "list:enum:campaign|sandbox", "effects": "effects"},
	},
	"buildings": {
		"file": "buildings.json", "list": "buildings",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "cost": "res_map",
			"build_turns": "int", "upkeep": "res_map", "effects": "effects", "unlock_tech": "?ref:techs",
			"unique": "?enum:colony|empire", "landmark": "?bool", "story": "?bool",
			"requires": "?enum:dome_world", "provides": "?list:enum:spaceport|market",
			"adjacency": "?list:obj:adjacency",
		},
	},
	"techs": {
		"file": "techs.json", "list": "techs",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "branch": "enum:physics|society|engineering",
			"tier": "int", "story": "?bool", "military": "?bool", "prereqs": "list:ref:techs",
			"effects": "effects",
		},
	},
	"hulls": {
		"file": "hulls.json", "list": "hulls",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon",
			"class": "enum:civilian|military", "role": "?enum:survey|construction|colony",
			"cost": "res_map", "upkeep": "res_map", "build_turns": "?int", "speed_cp": "int",
			"structure": "?int", "slots": "?obj:hull_slots", "evasion_bp": "?bp", "unlock_tech": "?ref:techs",
		},
	},
	"modules": {
		"file": "modules.json", "list": "modules",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "slot": "enum:S|M|L|U",
			"kind": "enum:kinetic|thermal|explosive|armour|shield|defence|utility", "damage": "?int",
			"armour": "?int", "shield": "?int", "regen_bp": "?bp", "intercept_bp": "?bp", "hit_bp": "?bp",
			"cost": "res_map", "unlock_tech": "?ref:techs",
		},
	},
	"edicts": {
		"file": "edicts.json", "list": "edicts",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "activation": "res_map",
			"upkeep": "res_map", "duration": "int", "effects": "effects", "requires_tech": "?ref:techs",
		},
	},
	"treaties": {"file": "treaties.json", "list": "treaties", "fields": {"id": "id", "name_key": "key", "desc_key": "key"}},
	"personalities": {"file": "personalities.json", "list": "personalities", "fields": {"id": "id"}},
	"difficulty": {
		"file": "difficulty.json", "list": "presets",
		"fields": {
			"id": "id", "name_key": "key", "desc_key": "key", "player_output_bp": "bp",
			"event_severity_bp": "bp", "pirate_strength_bp": "bp", "ai_aggression": "int",
			"ai_output_bp": "bp", "hints": "bool",
		},
	},
	"legacies": {
		"file": "legacies.json", "list": "legacies",
		"fields": {"id": "id", "name_key": "key", "desc_key": "key", "icon": "icon", "effects": "effects"},
	},
	"vignettes": {
		"file": "vignettes.json", "list": "vignettes",
		"fields": {
			"id": "id", "sky": "list:token", "ground": "token",
			"horizon": "enum:hills|plain|dunes|terraces|hall|vault|station|space|sea",
			"props": "list:enum:crowd|figure|figures|lamp|pods|crate|machines|drive|scaffold|beacon|ship|ships|dome|domes|tower|towers|banners|lectern|lights|fields|tent|ruins|drone|dish|comet|debris|planet|nebula|stars|column|market|slowboat|pylons|flare|stretchers|window",
			"accent": "enum:star|lamp|window|glow|flare|beacon|lantern",
			"accent_token": "token",
		},
	},
	"portraits": {
		"file": "portraits.json", "list": "portraits",
		"fields": {
			"id": "id", "name_key": "key", "kind": "enum:human|vael", "skin": "?hex", "hair": "?hex",
			"hair_style": "?enum:short|long|bun|shaved_side|cropped|swept|bald",
			"collar": "?token", "accessory": "?enum:none|glasses|scarf|badge|pin|plate",
			"age": "?enum:young|middle|older",
		},
	},
	"assets": {
		"file": "asset_manifest.json", "list": "assets",
		"fields": {
			"id": "id", "kind": "enum:sfx|music|vfx|vignette|portrait|ship|art|store",
			"status": "enum:placeholder|delivered", "file": "?str", "priority": "?bool", "optional": "?bool",
		},
	},
}

const OBJECTS: Dictionary = {
	"job_slot": {"job": "ref:jobs", "count": "int"},
	"adjacency": {"with": "ref:districts", "bonus_bp": "?bp", "cap_bp": "?bp", "stability_add": "?int", "housing_add": "?int"},
	"tier": {"tier": "int", "requires_tech": "ref:techs", "cost_mult_bp": "bp", "extra_jobs": "int", "output_bp": "bp", "housing_mult_bp": "?bp"},
	"effect": {"key": "str", "value": "int", "target": "?str", "turns": "?int", "over_turns": "?int"},
	"hull_slots": {"S": "?int", "M": "?int", "L": "?int", "U": "?int"},
}

## Fields whose string values are string-table keys, wherever they appear (tables, scenarios,
## events). Used by the string check and the orphan check.
const KEY_FIELDS: Array[String] = [
	"name_key", "desc_key", "label_key", "title_key", "body_key", "text_key", "note_key",
	"synopsis_key", "briefing_key",
]
