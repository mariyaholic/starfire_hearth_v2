extends SceneTree
## Direct fixture render; no manual play.
func _initialize() -> void:
	_launch.call_deferred()
func _launch() -> void:
	await process_frame
	var runner: GDScript = load("/workspace/starfire-evidence/m2e/runner.gd") as GDScript
	if runner == null:
		quit(1)
		return
	root.add_child(runner.new())
