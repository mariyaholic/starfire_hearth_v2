extends SceneTree
## SYNTHETIC INITIAL SETUP ONLY: actual OS controls perform all subsequent actions.
func _initialize() -> void:
	_seed.call_deferred()
func _seed() -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"m2a_expedition",23,"normal")
	state.turn=4
	var probe: Fleet=state.fleets["flt_0002"]
	probe.system_id="sys_ember"
	probe.path.assign(["sys_tessel","sys_halden"])
	probe.move_progress=1
	state.player().known_systems["sys_tessel"]=Empire.FOG_SURVEYED
	state.player().flags["auto_explore:flt_0002"]=1
	state.player().stock["minerals"]=30000
	state.player().stock["energy"]=30000
	var error: Error=root.get_node("SaveService").call("save","fixture_m2c_start",state)
	print("SYNTHETIC start: turn=4 probeSystem=Ember path=Tessel,Halden progress=1 auto=true remaining=%d saveError=%d" % [Travel.remaining_eta(state,"flt_0002").total,error])
	quit(0 if error==OK else 1)
