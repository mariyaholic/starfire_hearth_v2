extends SceneTree
## Aggregates bot telemetry and prints PASS / FAIL / SKIP for each gate of §12.
##   godot --headless --path . -s tools/telemetry_report.gd -- --in telemetry/ [--budget-ms 300]
## A gate is SKIP, with its reason, when the runs cannot measure it yet (for example, a stub
## scenario has no economy or objectives). Exits 1 on any FAIL.

const HOARD_TURNS: int = 10
const HOARD_STREAK: int = 10
const HOARD_MAX_RUN_SHARE: float = 0.2


func _initialize() -> void:
	var in_dir: String = "telemetry"
	var budget_ms: float = 300.0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--in" and i + 1 < args.size():
			in_dir = args[i + 1]
		if args[i] == "--budget-ms" and i + 1 < args.size():
			budget_ms = args[i + 1].to_float()
	var runs: Array[Dictionary] = _load_runs(in_dir)
	if runs.is_empty():
		printerr("telemetry_report: no telemetry files in %s" % in_dir)
		quit(2)
		return
	var lines: Array[String] = []
	var fails: int = 0
	var policies: Dictionary[String, int] = {}
	var stub: bool = true
	for r: Dictionary in runs:
		var pol: String = r["meta"]["policy"]
		policies[pol] = policies.get(pol, 0) + 1
		if str(r["meta"].get("scenario_status", "")) == "playable":
			stub = false
	print("telemetry_report: %d run(s) from %s; policies %s" % [runs.size(), in_dir, str(policies)])

	# Invariants: hard failures in any run.
	var problems: int = 0
	for r: Dictionary in runs:
		problems += int(r["summary"]["invariant_problems"])
	fails += _gate(lines, "invariants", problems == 0, "%d invariant problem(s) across runs" % problems)

	# Determinism: only where the runner replayed the seed.
	var checked: int = 0
	var nondet: int = 0
	for r: Dictionary in runs:
		if r["meta"].get("determinism_checked", false):
			checked += 1
			if not r["meta"].get("deterministic", false):
				nondet += 1
	if checked == 0:
		lines.append("SKIP  determinism: runs were not replayed (use bot_run --check-determinism)")
	else:
		fails += _gate(lines, "determinism", nondet == 0, "%d of %d replayed run(s) matched their first hashes" % [checked - nondet, checked])

	# Performance: p95 of end-turn time across all turns against the desktop budget.
	var times: Array[float] = []
	for r: Dictionary in runs:
		for row: Dictionary in r["turns"]:
			times.append(float(row["end_turn_ms"]))
	times.sort()
	var p95: float = times[mini(times.size() - 1, int(ceil(times.size() * 0.95)) - 1)]
	fails += _gate(lines, "performance", p95 < budget_ms, "end-turn p95 %.2f ms (budget %.0f ms, %d turns, desktop only)" % [p95, budget_ms, times.size()])

	# Balance gates need a playable scenario with an economy and objectives.
	var reason: String = "the scenario is a stub (no economy, builds or objectives before M1)"
	if stub:
		for g: String in ["no_hoarding", "everything_matters", "winnable", "pacing", "no_dead_turns"]:
			lines.append("SKIP  %s: %s" % [g, reason])
	else:
		fails += _no_hoarding(lines, runs)
		fails += _no_dead_turns(lines, runs)
		for g: String in ["everything_matters", "winnable", "pacing"]:
			lines.append("SKIP  %s: computed from M1 once objectives and builds report into telemetry" % g)
	for l: String in lines:
		print(l)
	quit(1 if fails > 0 else 0)


func _gate(lines: Array[String], name: String, ok: bool, detail: String) -> int:
	lines.append("%s  %s: %s" % ["PASS" if ok else "FAIL", name, detail])
	return 0 if ok else 1


## No resource stays above HOARD_TURNS turns of its gross income for more than HOARD_STREAK
## consecutive turns in more than HOARD_MAX_RUN_SHARE of runs.
func _no_hoarding(lines: Array[String], runs: Array[Dictionary]) -> int:
	var hoarding_runs: int = 0
	var measured: int = 0
	for r: Dictionary in runs:
		var streak: Dictionary[String, int] = {}
		var hoarded: bool = false
		var any_income: bool = false
		for row: Dictionary in r["turns"]:
			var income: Dictionary = row.get("income", {})
			var stocks: Dictionary = row.get("stocks", {})
			for res: Variant in income.keys():
				var gross: int = int(income[res])
				if gross <= 0:
					continue
				any_income = true
				if int(stocks.get(res, 0)) > gross * HOARD_TURNS:
					streak[res] = streak.get(res, 0) + 1
					if streak[res] > HOARD_STREAK:
						hoarded = true
				else:
					streak[res] = 0
		if any_income:
			measured += 1
			if hoarded:
				hoarding_runs += 1
	if measured == 0:
		lines.append("SKIP  no_hoarding: no run reported any income")
		return 0
	var share: float = hoarding_runs / float(measured)
	return _gate(lines, "no_hoarding", share <= HOARD_MAX_RUN_SHARE, "%d of %d run(s) hoarded (limit %d%%)" % [hoarding_runs, measured, int(HOARD_MAX_RUN_SHARE * 100)])


## Median share of turns without a meaningful decision in balanced runs is under 25%.
func _no_dead_turns(lines: Array[String], runs: Array[Dictionary]) -> int:
	var shares: Array[float] = []
	for r: Dictionary in runs:
		if r["meta"]["policy"] != "balanced":
			continue
		var dead: int = 0
		var n: int = 0
		for row: Dictionary in r["turns"]:
			n += 1
			if int(row.get("decisions_meaningful", 0)) < 2:
				dead += 1
		if n > 0:
			shares.append(dead / float(n))
	if shares.is_empty():
		lines.append("SKIP  no_dead_turns: no balanced runs")
		return 0
	shares.sort()
	var median: float = shares[shares.size() / 2]
	return _gate(lines, "no_dead_turns", median < 0.25, "median dead-turn share %.0f%% (limit 25%%)" % (median * 100.0))


func _load_runs(dir_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	var names: Array[String] = []
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f: String in names:
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(f)))
		if typeof(v) == TYPE_DICTIONARY and (v as Dictionary).has("summary"):
			out.append(v)
	return out
