extends RefCounted
## Schema 1 (M0) to schema 2 (M1): research, ordinances, build queues, governors, events,
## objectives and the other M1 fields, each filled with the value a new M1 game would have. An M0
## save holds only the stub start state, so every default is safe (DESIGN_LOG 52).

const BRANCHES: Array[String] = ["physics", "society", "engineering"]


static func migrate(state: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s["schema_version"] = 2
	_default(s, "difficulty_id", "normal")
	for key: String in ["modifiers", "event_memory", "objectives_done", "objective_progress"]:
		_default(s, key, {})
	for key: String in ["scheduled_effects", "events_pending", "events_scheduled", "event_log"]:
		_default(s, key, [])
	_default(s, "director_next", 0)
	_default(s, "outcome", "")
	_default(s, "outcome_turn", 0)
	_default(s, "outcome_reason", "")

	var colonies: Dictionary = s.get("colonies", {})
	var empires: Dictionary = s.get("empires", {})
	var colony_ids: Array = colonies.keys()
	colony_ids.sort()
	for eid: Variant in empires.keys():
		var e: Dictionary = empires[eid]
		if not e.has("capital_id"):
			e["capital_id"] = ""
			for cid: Variant in colony_ids:
				if str(colonies[cid].get("owner_id", "")) == str(eid):
					e["capital_id"] = str(cid)
					break
		if not e.has("research"):
			var rs: Dictionary = {}
			for b: String in BRANCHES:
				rs[b] = {"branch": b, "card": "", "progress": 0, "hand": [], "draws": 0}
			e["research"] = rs
		for key: String in ["tech_turns", "ordinances"]:
			_default(e, key, {})
		for key: String in ["surveyed_planets", "legacies"]:
			_default(e, key, [])
		_default(e, "decode_progress", 0)
		_default(e, "energy_short_turns", 0)
		if e["capital_id"] != "" and colonies.has(e["capital_id"]):
			var pid: String = str(colonies[e["capital_id"]].get("planet_id", ""))
			if pid != "" and not (e["surveyed_planets"] as Array).has(pid):
				(e["surveyed_planets"] as Array).append(pid)

	for cid: Variant in colonies.keys():
		var c: Dictionary = colonies[cid]
		_default(c, "queue", [])
		_default(c, "outpost_kind", "")
		_default(c, "founded_turn", 1)
		_default(c, "governor_on", false)
		_default(c, "governor_focus", "balanced")
		_default(c, "governor_budget_bp", 5000)
		_default(c, "governor_funds", 0)
		_default(c, "governor_vetoes", {})
		_default(c, "famine_turns", 0)
		_default(c, "autonomy_turns", 0)
		_default(c, "autonomous_from", "")
		for d: Variant in c.get("districts", []):
			_default(d, "branch", "")

	var ships: Dictionary = s.get("ships", {})
	for shid: Variant in ships.keys():
		var sh: Dictionary = ships[shid]
		_default(sh, "hull", "")
		_default(sh, "task", "")
		_default(sh, "task_target", "")
		_default(sh, "task_param", "")
		_default(sh, "task_turns", 0)
	return s


static func _default(d: Dictionary, key: String, value: Variant) -> void:
	if not d.has(key):
		d[key] = value
