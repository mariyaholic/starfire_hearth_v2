extends SceneTree
## Prints the state hash (first 12 hex digits) after one turn of Scenario 1, seed 1, Normal, with
## no orders: what the web build's smoke run must reach too, so the browser and the desktop agree.
##   godot --headless --path . -s tools/smoke_hash.gd


func _initialize() -> void:
	var st: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 1, "normal")
	var r: TurnResult = TurnProcessor.run(st, [] as Array[Command])
	print(r.state_hash.left(12))
	quit(0)
