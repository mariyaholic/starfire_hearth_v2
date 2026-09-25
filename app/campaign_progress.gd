class_name CampaignProgress
extends RefCounted
## The campaign's progress (§10.1): which scenarios are won, the legacy picked at each debrief, and
## the difficulty preset. Scenarios run in order and each win unlocks the next. The flow screens
## read it; the debrief records wins and legacies. Loaded from a file (user://campaign.json in
## the game), it writes itself back after every change.

const ORDER: Array[String] = ["s1_first_light", "s2_the_crossing", "s3_neighbours"]
const PATH: String = "user://campaign.json"

var difficulty_id: String = "normal"
## The file this progress was loaded from and saves to; "" keeps it in memory (tests).
var file_path: String = ""
## Scenario id -> the legacy id picked at its debrief ("" until one is picked).
var won: Dictionary[String, String] = {}


func is_won(scenario_id: String) -> bool:
	return won.has(scenario_id)


## The first scenario is always open; each later one opens when the one before it is won.
func is_unlocked(scenario_id: String) -> bool:
	var i: int = ORDER.find(scenario_id)
	if i <= 0:
		return i == 0
	return is_won(ORDER[i - 1])


## The scenario that must be won before this one, or "" for the first.
func previous_of(scenario_id: String) -> String:
	var i: int = ORDER.find(scenario_id)
	return ORDER[i - 1] if i > 0 else ""


func legacy_of(scenario_id: String) -> String:
	return won.get(scenario_id, "")


## The legacies a scenario starts with: the one picked after each earlier scenario.
func carried_legacies(scenario_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ORDER:
		if id == scenario_id:
			break
		if not legacy_of(id).is_empty():
			out.append(legacy_of(id))
	return out


## A win counts as soon as the debrief opens, so leaving before picking a legacy keeps it.
func record_win(scenario_id: String) -> void:
	if not won.has(scenario_id):
		won[scenario_id] = ""
		_changed()


## Replaying a won scenario lets the player pick again; the new pick replaces the old one.
func pick_legacy(scenario_id: String, legacy_id: String) -> void:
	won[scenario_id] = legacy_id
	_changed()


func set_difficulty(id: String) -> void:
	if id != difficulty_id:
		difficulty_id = id
		_changed()


func to_dict() -> Dictionary:
	var w: Dictionary = {}
	for id: String in won.keys():
		w[id] = won[id]
	return {"version": 1, "difficulty": difficulty_id, "won": w}


static func from_dict(d: Dictionary) -> CampaignProgress:
	var p: CampaignProgress = CampaignProgress.new()
	p.difficulty_id = DictIO.str_of(d, "difficulty", "normal")
	var w: Dictionary = DictIO.dict_of(d, "won")
	for id: Variant in w.keys():
		if ORDER.has(str(id)):
			p.won[str(id)] = str(w[id])
	return p


## The progress saved at `path`, or a fresh one (a missing or unreadable file starts over);
## either way it saves back to `path`.
static func load_file(path: String = PATH) -> CampaignProgress:
	var p: CampaignProgress = CampaignProgress.new()
	if FileAccess.file_exists(path):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(v) == TYPE_DICTIONARY:
			p = from_dict(v)
	p.file_path = path
	return p


func save_file() -> Error:
	if file_path.is_empty():
		return OK
	var f: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "  ") + "\n")
	f.close()
	return OK


func _changed() -> void:
	save_file()
