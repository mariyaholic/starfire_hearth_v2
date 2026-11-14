extends SceneTree
## Synthetic INITIAL SETUP ONLY. Subsequent test actions use actual OS controls.
func _initialize() -> void:
	_seed.call_deferred()
func _seed() -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"m2a_expedition",17,"normal")
	state.turn=2
	var fleet: Fleet=state.fleets["flt_0001"]
	fleet.system_id="sys_tessel"
	fleet.path.assign(["sys_halden"])
	fleet.move_progress=Travel.leg_turns(Travel.lane_between(state,state.player_id,"sys_tessel","sys_halden"),Travel.fleet_speed(state,fleet))-1
	state.player().known_systems["sys_tessel"]=Empire.FOG_SURVEYED
	state.player().stock["minerals"]=49000
	state.player().stock["energy"]=30000
	var error: Error=root.get_node("SaveService").call("save","fixture_m2b_start",state)
	print("Fixture initialsetup saved error=%d turn=%d constructionremaining=1 probeidle=true" % [error,state.turn])
	quit(0 if error==OK else 1)
