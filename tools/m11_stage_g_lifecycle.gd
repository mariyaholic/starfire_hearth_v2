extends SceneTree
## Defer the stress runner until the project autoloads are active.

func _initialize() -> void:
	_launch.call_deferred()


func _launch() -> void:
	await process_frame
	var script: GDScript = load("res://tools/m11_stage_g_lifecycle_runner.gd") as GDScript
	if script == null:
		printerr("m11_stage_g_lifecycle: could not load runner")
		quit(2)
		return
	root.add_child(script.new())
