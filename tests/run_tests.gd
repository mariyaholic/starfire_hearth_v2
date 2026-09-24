extends SceneTree
## Headless test runner.
##   godot --headless --path . -s tests/run_tests.gd [-- --filter <text>]
## Discovers tests/**/test_*.gd and runs every method named test_* with a T helper. Engine and
## script errors raised while a test runs are captured through a Logger and fail that test.
## Exits with code 1 if anything failed.

const TEST_ROOT: String = "res://tests"


class ErrorCatcher:
	extends Logger
	var _mutex: Mutex = Mutex.new()
	var _errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text: String = rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var out: Array[String] = _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return out


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--filter" and i + 1 < args.size():
			filter = args[i + 1]
	var catcher: ErrorCatcher = ErrorCatcher.new()
	OS.add_logger(catcher)

	var files: Array[String] = []
	_discover(TEST_ROOT, files)
	files.sort()
	var passed: int = 0
	var failed: int = 0
	var checks: int = 0
	var failed_names: Array[String] = []
	var started: int = Time.get_ticks_msec()
	for path: String in files:
		var script: GDScript = load(path)
		var load_errors: Array[String] = catcher.take()
		if script == null or not script.can_instantiate():
			failed += 1
			failed_names.append(path)
			print("FAIL %s: script failed to load %s" % [path, str(load_errors)])
			continue
		var methods: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and not methods.has(mname):
				methods.append(mname)
		methods.sort()
		var file_matches: bool = filter.is_empty() or path.get_file().contains(filter)
		for mname: String in methods:
			if not file_matches and not mname.contains(filter):
				continue
			var inst: Object = script.new()
			var t: T = T.new()
			catcher.take()
			var t0: int = Time.get_ticks_usec()
			await inst.call(mname, t)
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			var errs: Array[String] = catcher.take()
			for e: String in errs:
				t.failures.append("engine error: " + e)
			checks += t.checks
			var label: String = "%s::%s" % [path.trim_prefix(TEST_ROOT + "/"), mname]
			if t.failures.is_empty():
				passed += 1
				if ms > 500.0:
					print("  slow %s (%.0f ms)" % [label, ms])
			else:
				failed += 1
				failed_names.append(label)
				print("FAIL %s" % label)
				for f: String in t.failures:
					print("     - %s" % f)
			if inst is Node:
				(inst as Node).free()
	var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print("%d passed, %d failed, %d checks, %d files, %.1f s" % [passed, failed, checks, files.size(), elapsed])
	if failed > 0:
		print("Failed: ")
		for n: String in failed_names:
			print("  " + n)
	OS.remove_logger(catcher)
	quit(1 if failed > 0 else 0)


func _discover(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_discover(dir_path.path_join(sub), out)
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
