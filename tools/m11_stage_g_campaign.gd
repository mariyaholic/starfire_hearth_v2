extends SceneTree
## Load the campaign runner after the tool SceneTree has completed autoload initialization.

func _initialize() -> void:
	_launch.call_deferred()


func _launch() -> void:
	await process_frame
	var runner_script: GDScript = load("res://tools/m11_stage_g_campaign_runner.gd") as GDScript
	if runner_script == null:
		printerr("m11_stage_g_campaign: could not load campaign runner")
		quit(2)
		return
	root.add_child(runner_script.new())
