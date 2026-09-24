extends SceneTree
## Data validation (§9.8): schema shape, cross-references, string keys both ways, two sinks per
## resource, closed effect keys, icon files, colour tokens, scenario reachability.
##   godot --headless --path . -s tools/validate_data.gd
## Exits 1 if there is any error. SKIP lines are checks that cannot run yet and say why.


func _initialize() -> void:
	var rep: DataChecks.Report = DataChecks.run()
	for e: String in rep.errors:
		print("ERROR ", e)
	for s: String in rep.skips:
		print("SKIP  ", s)
	print("validate_data: %d tables, %d records, %d strings: %d error(s), %d skipped check(s)" % [
		rep.tables, rep.records, rep.strings, rep.errors.size(), rep.skips.size()])
	quit(1 if not rep.errors.is_empty() else 0)
