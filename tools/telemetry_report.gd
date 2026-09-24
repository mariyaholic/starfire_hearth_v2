extends SceneTree
## Aggregates bot telemetry and prints PASS / FAIL / SKIP for each gate of §12.
##   godot --headless --path . -s tools/telemetry_report.gd -- --in telemetry/ [--budget-ms 300]
##       [--balance strict|advisory]
## A gate is SKIP, with its reason, when the runs cannot measure it yet. Exits 1 on any FAIL; with
## --balance advisory the five balance gates are still computed and printed, but only the
## invariant, determinism and performance gates decide the exit code (used while tuning).

const HOARD_TURNS: int = 10
const HOARD_STREAK: int = 10
const HOARD_MAX_RUN_SHARE: float = 0.2
const STOCKED: Array[String] = ["food", "energy", "minerals", "alloys", "influence"]
## "Winnable" counts a win within this multiple of the expected duration (DESIGN_LOG 63).
const WIN_CAP_BP: int = 15000
const BUILT_MIN_SHARE: float = 0.25
const TECH_MIN_SHARE: float = 0.15


func _initialize() -> void:
	var in_dir: String = "telemetry"
	var budget_ms: float = 300.0
	var strict_balance: bool = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--in" and i + 1 < args.size():
			in_dir = args[i + 1]
		if args[i] == "--budget-ms" and i + 1 < args.size():
			budget_ms = args[i + 1].to_float()
		if args[i] == "--balance" and i + 1 < args.size():
			strict_balance = args[i + 1] != "advisory"
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
		var balance_fails: int = 0
		balance_fails += _no_hoarding(lines, runs)
		balance_fails += _everything_matters(lines, runs)
		balance_fails += _winnable(lines, runs)
		balance_fails += _pacing(lines, runs)
		balance_fails += _no_dead_turns(lines, runs)
		if strict_balance:
			fails += balance_fails
		elif balance_fails > 0:
			lines.append("NOTE  %d balance gate(s) failed; advisory mode, so they do not fail this run" % balance_fails)
	for l: String in lines:
		print(l)
	quit(1 if fails > 0 else 0)


func _gate(lines: Array[String], name: String, ok: bool, detail: String) -> int:
	lines.append("%s  %s: %s" % ["PASS" if ok else "FAIL", name, detail])
	return 0 if ok else 1


## No resource stays above HOARD_TURNS turns of its gross income for more than HOARD_STREAK
## consecutive turns in more than HOARD_MAX_RUN_SHARE of runs. Random-legal runs are left out:
## that bot never manages its stocks, by design (DESIGN_LOG 82).
func _no_hoarding(lines: Array[String], runs: Array[Dictionary]) -> int:
	var hoarding_runs: int = 0
	var measured: int = 0
	var by_res: Dictionary[String, int] = {}
	for r: Dictionary in runs:
		if r["meta"]["policy"] == "random-legal":
			continue
		var streak: Dictionary[String, int] = {}
		var hoarded: bool = false
		var any_income: bool = false
		for row: Dictionary in r["turns"]:
			var gross_all: Dictionary = row.get("gross", {})
			var stocks: Dictionary = row.get("stocks", {})
			for res: String in STOCKED:
				var gross: int = int(gross_all.get(res, 0))
				if gross <= 0:
					streak[res] = 0
					continue
				any_income = true
				if int(stocks.get(res, 0)) > gross * HOARD_TURNS:
					streak[res] = streak.get(res, 0) + 1
					if streak[res] > HOARD_STREAK:
						hoarded = true
						by_res[res] = by_res.get(res, 0) + 1 if streak[res] == HOARD_STREAK + 1 else by_res.get(res, 0)
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
	return _gate(lines, "no_hoarding", share <= HOARD_MAX_RUN_SHARE, "%d of %d run(s) hoarded (limit %d%%); streaks by resource %s" % [hoarding_runs, measured, int(HOARD_MAX_RUN_SHARE * 100), str(by_res)])


## Every district and building in the scenario's balance scope is built in at least 25% of runs,
## and every tech in it is researched in at least 15% (DESIGN_LOG 64).
func _everything_matters(lines: Array[String], runs: Array[Dictionary]) -> int:
	var db: ContentDb = ContentDb.load_from()
	var scope: Dictionary = DictIO.dict_of(db.scenarios.get(str(runs[0]["meta"]["scenario"]), {}), "balance_scope")
	var built: Dictionary[String, int] = {}
	var teched: Dictionary[String, int] = {}
	for r: Dictionary in runs:
		var rows: Array = r["turns"]
		if rows.is_empty():
			continue
		var start: Dictionary = rows[0].get("built", {})
		var seen: Dictionary[String, bool] = {}
		for row: Dictionary in rows:
			var b: Dictionary = row.get("built", {})
			for id: Variant in b.keys():
				if int(b[id]) > int(start.get(id, 0)):
					seen[str(id)] = true
		for id2: String in seen.keys():
			built[id2] = built.get(id2, 0) + 1
		for t: Variant in rows[rows.size() - 1].get("techs", []):
			teched[str(t)] = teched.get(str(t), 0) + 1
	var n: float = float(runs.size())
	var low: Array[String] = []
	for kind: String in ["districts", "buildings"]:
		for id3: Variant in DictIO.arr_of(scope, kind):
			var share: float = built.get(str(id3), 0) / n
			if share < BUILT_MIN_SHARE:
				low.append("%s %d%%" % [str(id3), int(share * 100)])
	for id4: Variant in DictIO.arr_of(scope, "techs"):
		var share2: float = teched.get(str(id4), 0) / n
		if share2 < TECH_MIN_SHARE:
			low.append("%s %d%%" % [str(id4), int(share2 * 100)])
	var detail: String = "every scoped district, building and tech used often enough" if low.is_empty() else "too rarely used: " + ", ".join(low)
	return _gate(lines, "everything_matters", low.is_empty(), detail)


## Balanced wins 60-90% on Normal, random-legal under 20%, balanced 85-100% on Story (when those
## runs exist). A win counts within 1.5x the expected duration.
func _winnable(lines: Array[String], runs: Array[Dictionary]) -> int:
	var fails: int = 0
	var bands: Array = [["balanced", "normal", 0.60, 0.90], ["random-legal", "normal", 0.0, 0.1999], ["balanced", "story", 0.85, 1.0]]
	for band: Array in bands:
		var total: int = 0
		var wins: int = 0
		for r: Dictionary in runs:
			if r["meta"]["policy"] != band[0] or str(r["meta"].get("difficulty", "normal")) != band[1]:
				continue
			total += 1
			var cap: int = Fx.div_floor(int(r["summary"].get("expected_turns", 0)) * WIN_CAP_BP, 10000)
			if str(r["summary"].get("outcome", "")) == "won" and int(r["summary"].get("outcome_turn", 0)) <= cap:
				wins += 1
		var name: String = "winnable (%s, %s)" % [band[0], band[1]]
		if total == 0:
			lines.append("SKIP  %s: no runs" % name)
			continue
		var rate: float = wins / float(total)
		fails += _gate(lines, name, rate >= float(band[2]) and rate <= float(band[3]), "%d of %d won (%d%%; band %d-%d%%)" % [wins, total, int(rate * 100), int(float(band[2]) * 100), int(ceil(float(band[3]) * 100))])
	return fails


## The median win turn of balanced Normal runs is within 20% of the expected duration.
func _pacing(lines: Array[String], runs: Array[Dictionary]) -> int:
	var turns: Array[int] = []
	var expected: int = 0
	for r: Dictionary in runs:
		if r["meta"]["policy"] != "balanced" or str(r["meta"].get("difficulty", "normal")) != "normal":
			continue
		expected = int(r["summary"].get("expected_turns", 0))
		if str(r["summary"].get("outcome", "")) == "won":
			turns.append(int(r["summary"]["outcome_turn"]))
	if turns.is_empty() or expected <= 0:
		lines.append("SKIP  pacing: no balanced wins on Normal")
		return 0
	turns.sort()
	var median: int = turns[turns.size() / 2]
	var lo: int = Fx.div_floor(expected * 8000, 10000)
	var hi: int = Fx.div_ceil(expected * 12000, 10000)
	return _gate(lines, "pacing", median >= lo and median <= hi, "median win turn %d (expected %d, band %d-%d)" % [median, expected, lo, hi])


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
