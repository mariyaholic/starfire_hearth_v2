class_name TelemetryCoverage
extends RefCounted
## Explicit caller-supplied coverage contract; ad hoc reports need not provide one.


## Parse comma-separated seeds and inclusive ranges; empty output means invalid input.
static func seeds(spec: String) -> Array[int]:
	var out: Array[int] = []
	for part: String in spec.split(",", false):
		var ends: PackedStringArray = part.split("-")
		if ends.size() < 1 or ends.size() > 2 or not ends[0].is_valid_int():
			return []
		var first: int = ends[0].to_int()
		var last: int = first
		if ends.size() == 2:
			if not ends[1].is_valid_int(): return []
			last = ends[1].to_int()
		if first < 0 or last < first or last > GameState.MAX_SEED or last - first > 10000:
			return []
		for seed: int in range(first, last + 1):
			if out.has(seed): return []
			out.append(seed)
	out.sort()
	return out


## Each group is policy:difficulty:count. When supplied, seeds specifies its exact seed set.
static func errors(runs: Array[Dictionary], groups: Array[String], expected_seeds: Array[int], expected_runs: int, require_determinism: bool, expected_scenario: String = "") -> Array[String]:
	var problems: Array[String] = []
	if expected_runs >= 0 and runs.size() != expected_runs:
		problems.append("expected %d runs, found %d" % [expected_runs, runs.size()])
	if not expected_scenario.is_empty():
		for run: Dictionary in runs:
			if DictIO.str_of(DictIO.dict_of(run, "meta"), "scenario") != expected_scenario:
				problems.append("run belongs to a different scenario than %s" % expected_scenario)
	var checked_groups: Dictionary[String, bool] = {}
	for group: String in groups:
		var parts: PackedStringArray = group.split(":")
		if parts.size() != 3 or parts[0].is_empty() or parts[1].is_empty() or not parts[2].is_valid_int() or parts[2].to_int() < 1:
			problems.append("invalid expected group %s (use policy:difficulty:count)" % group)
			continue
		var key: String = parts[0] + ":" + parts[1]
		if checked_groups.has(key):
			problems.append("duplicate expected group %s" % key)
			continue
		checked_groups[key] = true
		var count: int = 0
		var observed: Array[int] = []
		for run: Dictionary in runs:
			var meta: Dictionary = DictIO.dict_of(run, "meta")
			if DictIO.str_of(meta, "policy") != parts[0] or DictIO.str_of(meta, "difficulty", "normal") != parts[1]:
				continue
			count += 1
			var seed: int = DictIO.int_of(meta, "seed", -1)
			if observed.has(seed): problems.append("duplicate seed %d in %s" % [seed, key])
			observed.append(seed)
		observed.sort()
		if count != parts[2].to_int():
			problems.append("expected %s count %d, found %d" % [key, parts[2].to_int(), count])
		if not expected_seeds.is_empty() and observed != expected_seeds:
			problems.append("expected %s seeds %s, found %s" % [key, str(expected_seeds), str(observed)])
	if require_determinism:
		var unchecked: int = 0
		for run: Dictionary in runs:
			var meta: Dictionary = DictIO.dict_of(run, "meta")
			if typeof(meta.get("determinism_checked")) != TYPE_BOOL or not meta["determinism_checked"]:
				unchecked += 1
		if unchecked > 0: problems.append("%d runs lack determinism replay" % unchecked)
	return problems
