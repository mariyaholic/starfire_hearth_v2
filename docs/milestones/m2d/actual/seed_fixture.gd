extends SceneTree
## SYNTHETIC INITIAL SETUP ONLY. Surveyed gas giant, probe progress 1 and builder progress 0.
func _initialize() -> void:
	_seed.call_deferred()
func _seed() -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"m2a_expedition",31,"normal")
	state.turn=2
	state.player().known_systems["sys_vesper"]=Empire.FOG_SURVEYED
	state.player().surveyed_planets.append("pl_shroud_giant")
	for fid: String in ["flt_0001","flt_0002"]:
		var f: Fleet=state.fleets[fid]
		f.system_id="sys_vesper"
		f.path.assign(["sys_shroud"])
		f.move_progress=0 if fid=="flt_0001" else 1
	state.player().stock["energy"]=20000
	state.player().stock["minerals"]=30000
	state.player().stock["food"]=20000
	state.player().stock["alloys"]=10000
	state.player().stock["influence"]=10000
	var error: Error=root.get_node("SaveService").call("save","fixture_m2d_start",state)
	print("SYNTHETIC turn2 setup: Shroudunknown giantpreSurveyed, probeRemaining=%d builderRemaining=%d saveError=%d" % [Travel.remaining_eta(state,"flt_0002").total,Travel.remaining_eta(state,"flt_0001").total,error])
	quit(0 if error==OK else 1)
