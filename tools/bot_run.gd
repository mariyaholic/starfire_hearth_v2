extends SceneTree
## Headless bot playthroughs -> telemetry JSON (§13.7).
##   godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy balanced --seeds 1-20 --turns 60 --out telemetry/
## Options: --check-determinism replays every seed and fails if the final hash differs.
## Exits 1 if any run broke an invariant or was not deterministic.


func _initialize() -> void:
	var opts: Dictionary = _parse(OS.get_cmdline_user_args())
	var db: ContentDb = ContentDb.load_from()
	if not db.errors.is_empty():
		printerr("bot_run: data has load errors; run tools/validate_data.gd")
		quit(2)
		return
	var scenario_id: String = BotRunner.resolve_scenario(db, str(opts["scenario"]))
	if scenario_id.is_empty():
		printerr("bot_run: unknown scenario \"%s\"" % opts["scenario"])
		quit(2)
		return
	var policy: String = opts["policy"]
	if not BotPolicy.is_known(policy):
		printerr("bot_run: unknown policy \"%s\" (known: %s)" % [policy, ", ".join(BotPolicy.POLICIES)])
		quit(2)
		return
	var out_dir: String = opts["out"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var failed: bool = false
	for game_seed: int in opts["seeds"]:
		var run: BotRunner.Run = BotRunner.run(db, scenario_id, policy, game_seed, opts["turns"])
		var doc: Dictionary = run.to_dict()
		if opts["check_determinism"]:
			var again: BotRunner.Run = BotRunner.run(db, scenario_id, policy, game_seed, opts["turns"])
			var same: bool = again.hashes == run.hashes
			doc["meta"]["determinism_checked"] = true
			doc["meta"]["deterministic"] = same
			if not same:
				failed = true
				printerr("bot_run: seed %d is not deterministic" % game_seed)
		var s: Dictionary = run.summary()
		if int(s["invariant_problems"]) > 0:
			failed = true
			for p: String in run.problems.slice(0, 10):
				printerr("  ", p)
		var path: String = out_dir.path_join("%s_%s_seed%d.json" % [scenario_id, policy, game_seed])
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(doc, " ", false) + "\n")
		f.close()
		print("%s %s seed %d: %d turns, %d invariant problem(s), end turn mean %.2f ms p95 %.2f ms -> %s" % [
			scenario_id, policy, game_seed, s["turns"], s["invariant_problems"], s["end_turn_ms_mean"], s["end_turn_ms_p95"], path])
	quit(1 if failed else 0)


func _parse(args: PackedStringArray) -> Dictionary:
	var o: Dictionary = {
		"scenario": "s1", "policy": "balanced", "seeds": [1], "turns": 60,
		"out": "telemetry", "check_determinism": false,
	}
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--scenario":
				o["scenario"] = next
				i += 1
			"--policy":
				o["policy"] = next
				i += 1
			"--turns":
				o["turns"] = next.to_int()
				i += 1
			"--out":
				o["out"] = next
				i += 1
			"--seeds":
				o["seeds"] = _seeds(next)
				i += 1
			"--check-determinism":
				o["check_determinism"] = true
		i += 1
	return o


## "1-20" or "3,7,9" or "5".
func _seeds(text: String) -> Array[int]:
	var out: Array[int] = []
	for part: String in text.split(","):
		if part.contains("-"):
			var ab: PackedStringArray = part.split("-")
			for n in range(ab[0].to_int(), ab[1].to_int() + 1):
				out.append(n)
		elif not part.is_empty():
			out.append(part.to_int())
	return out
