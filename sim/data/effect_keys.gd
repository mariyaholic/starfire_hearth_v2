class_name EffectKeys
extends RefCounted
## The closed set of effect keys (§13.3). Content never contains expressions: an effect is
## {key, value, target?}. Extend this list only together with the code that applies the key, its
## tests and its Codex text.
##
## Keys ending in ":" take a parameter after the colon, e.g. "resource_output_bp:food".

const PLAIN: Array[String] = [
	"output_bp", "stability_add", "growth_bp", "housing_add",
	"unlock_building", "unlock_district_tier", "unlock_module", "unlock_hull",
	"edict_slots_add", "treaty_slots_add",
	"influence_per_turn_add", "outpost_cost_bp", "sensor_range_add",
	"noise_add", "noise_transit_bp", "decode_progress_add",
	"hit_chance_bp",
	"set_flag", "clear_flag", "spawn_event",
	"add_pops", "remove_pops",
	"clear_blocked_slot", "add_trait", "remove_trait",
	# Added in M0 for planet traits (DESIGN_LOG): slot count and ship cost modifiers.
	"slots_add", "ship_cost_bp",
	# Added in M1: the Archive's decode rate, outpost build time, and story buildings.
	"decode_rate_bp", "outpost_time_bp", "add_building",
]

const PARAMETRIC: Array[String] = [
	"resource_output_bp:", "district_output_bp:", "cap_add:", "opinion_add:", "damage_bp:",
	"research_bp:", "add_stock:",
	# Added in M1: a flat amount of a resource every turn (the Ark Hull, Hydroponics Bay).
	"output_add:",
]


static func is_valid(key: String) -> bool:
	if PLAIN.has(key):
		return true
	for prefix: String in PARAMETRIC:
		if key.begins_with(prefix) and key.length() > prefix.length():
			return true
	return false
