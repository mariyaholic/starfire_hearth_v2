extends SceneTree
## Re-baselines golden files. Run only on purpose, and log every re-baseline in CHANGELOG.md with
## the reason (§9.8).
##   godot --headless --path . -s tools/regen_golden.gd -- --reason "why the output changed"
##   ... -- --fixture-save   also freezes a fixture save of the current schema version
## RNG vectors are never regenerated here: they come from an independent reference.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var reason: String = ""
	var fixture: bool = false
	for i in args.size():
		if args[i] == "--reason" and i + 1 < args.size():
			reason = args[i + 1]
		if args[i] == "--fixture-save":
			fixture = true
	if reason.is_empty():
		printerr("regen_golden: --reason \"...\" is required")
		quit(2)
		return
	var hashes: Array[String] = GoldenScript.tiny_hashes()
	var doc: Dictionary = {
		"version": 1,
		"seed": GoldenScript.TINY_SEED,
		"turns": GoldenScript.TINY_TURNS,
		"schema_version": GameState.SCHEMA_VERSION,
		"reason": reason,
		"hashes": hashes,
	}
	_write(GoldenScript.TINY_PATH, JSON.stringify(doc, "  ", true) + "\n")
	print("wrote %s (%d hashes)" % [GoldenScript.TINY_PATH, hashes.size()])
	var s1: Array[String] = GoldenScript.s1_hashes()
	var s1_doc: Dictionary = {
		"version": 1,
		"seed": GoldenScript.S1_SEED,
		"turns": GoldenScript.S1_TURNS,
		"schema_version": GameState.SCHEMA_VERSION,
		"reason": reason,
		"hashes": s1,
	}
	_write(GoldenScript.S1_PATH, JSON.stringify(s1_doc, "  ", true) + "\n")
	print("wrote %s (%d hashes)" % [GoldenScript.S1_PATH, s1.size()])
	if fixture:
		var path: String = "res://tests/fixtures/saves/s1_v%d.json" % GameState.SCHEMA_VERSION
		_write(path, SaveSerializer.to_text(GoldenScript.s1_state(), "fixture") + "\n")
		print("wrote %s" % path)
	quit(0)


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("regen_golden: cannot write %s" % path)
		quit(1)
		return
	f.store_string(text)
	f.close()
