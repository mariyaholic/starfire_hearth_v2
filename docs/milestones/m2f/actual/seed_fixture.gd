extends SceneTree
## SYNTHETIC INITIAL SETUP ONLY: near-victory turn40, developed Vesper, resolved memories,
## Research outpost building on surveyed Veil (3 turns), probe partway Ember->Vesper.
func _initialize() -> void:
 _seed.call_deferred()
func _seed() -> void:
 var s: GameState=ScenarioLoader.build(Content.db(), "m2a_expedition", 57, "normal")
 s.turn=40
 for sid: String in s.systems:s.player().known_systems[sid]=Empire.FOG_SURVEYED
 for pid: String in s.planets:
  if not s.player().surveyed_planets.has(pid):s.player().surveyed_planets.append(pid)
 s.player().techs.append("habitat_domes")
 var vesper: Colony=Colony.from_dict(s.colonies["col_0001"].to_dict())
 vesper.id=s.next_id("col");vesper.planet_id="pl_vesper";vesper.pops=6;vesper.stability=70;vesper.buildings.clear()
 s.colonies[vesper.id]=vesper;s.planets["pl_vesper"].colony_id=vesper.id
 for d: Dictionary in Objectives.definitions(s):
  if DictIO.bool_of(d,"required"):s.objectives_done[DictIO.str_of(d,"id")]=39
 s.flags["m2a_halden_resolved"]=35;s.flags["m2a_halden_salvage"]=35;s.event_memory["m2a_halden_cache"]=35
 s.flags["m2a_shroud_resolved"]=36;s.flags["m2a_shroud_supplies"]=36;s.event_memory["m2a_shroud_derelict"]=36
 var builder: Ship=s.ships["shp_0001"]
 s.fleets[builder.fleet_id].system_id="sys_shroud"
 builder.task=Ship.TASK_OUTPOST;builder.task_target="pl_shroud_giant";builder.task_param="research";builder.task_turns=3
 var probe: Fleet=s.fleets["flt_0002"]
 probe.system_id="sys_ember";probe.path.assign(["sys_vesper"]);probe.move_progress=1
 for res: String in ["energy","minerals","food","alloys","influence"]:s.player().stock[res]=20000
 var err: Error=root.get_node("SaveService").call("save","fixture_m2f_nearwin",s)
 print("SYNTHETIC M2F turn40: goalsdone=%d developedVesper=%s builderResearch=%d probeProgress=%d ETA=%d saveError=%d" % [s.objectives_done.size(),ColonyRules.is_developed(vesper),builder.task_turns,probe.move_progress,Travel.remaining_eta(s,probe.id).total,err])
 quit(0 if err==OK else 1)
