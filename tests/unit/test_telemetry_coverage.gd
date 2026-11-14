extends RefCounted
## CI may demand its known matrix without imposing it on ad hoc telemetry runs.


func _run(seed: int, policy: String, checked: bool = true) -> Dictionary:
	return {"meta": {"seed": seed, "policy": policy, "difficulty": "normal", "scenario_status": "stub", "determinism_checked": checked, "deterministic": true}, "summary": {"invariant_problems": 0}, "turns": [{"end_turn_ms": 1}]}


func test_expected_groups_seeds_and_replays_fail_closed(t: T) -> void:
	var groups: Array[String] = ["balanced:normal:2", "random-legal:normal:2"]
	var runs: Array[Dictionary] = [_run(1, "balanced"), _run(2, "balanced"), _run(1, "random-legal")]
	var seeds: Array[int] = TelemetryCoverage.seeds("1-2")
	var issues: Array[String] = TelemetryCoverage.errors(runs, groups, seeds, 4, true)
	t.ok(str(issues).contains("expected 4 runs, found 3"))
	t.ok(str(issues).contains("random-legal:normal count 2, found 1"))
	t.ok(str(issues).contains("random-legal:normal seeds"))
	runs.append(_run(2, "random-legal", false))
	issues = TelemetryCoverage.errors(runs, groups, seeds, 4, true)
	t.ok(str(issues).contains("lack determinism replay"))
	runs[3] = _run(2, "random-legal")
	t.eq(TelemetryCoverage.errors(runs, groups, seeds, 4, true), [])
	t.ok(str(TelemetryCoverage.errors(runs, groups, seeds, 4, true, "s1_first_light")).contains("different scenario"))
	runs[3] = _run(1, "random-legal")
	t.ok(str(TelemetryCoverage.errors(runs, groups, seeds, 4, true)).contains("duplicate seed"))


func test_invalid_coverage_spec_is_rejected(t: T) -> void:
	t.eq(TelemetryCoverage.seeds("1-3,5"), [1, 2, 3, 5])
	t.eq(TelemetryCoverage.seeds("1-3,3"), [])
	t.eq(TelemetryCoverage.seeds("1-1000000"), [])
	var runs: Array[Dictionary] = [_run(1, "balanced")]
	var malformed: Array[String] = ["balanced:normal:0"]
	t.ok(not TelemetryCoverage.errors(runs, malformed, [] as Array[int], -1, false).is_empty())


func test_cli_exits_nonzero_for_missing_expected_file_and_group(t: T) -> void:
	var path: String = OS.get_user_data_dir().path_join("audit_telemetry_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(path)
	var file: FileAccess = FileAccess.open(path.path_join("first.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_run(1, "balanced")))
	file.close()
	var argv: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/telemetry_report.gd", "--", "--in", path, "--balance", "advisory", "--expect-runs", "2", "--expect-group", "random-legal:normal:1"]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), argv, output, true)
	t.eq(code, 1, "missing explicit coverage fails even with advisory balance")
	t.ok(str(output).contains("FAIL  coverage"))
	DirAccess.remove_absolute(path.path_join("first.json"))
	DirAccess.remove_absolute(path)
