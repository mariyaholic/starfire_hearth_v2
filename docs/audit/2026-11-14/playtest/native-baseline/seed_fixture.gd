extends SceneTree
## SYNTHETIC INITIAL SETUP ONLY: normal preview scenario at turn2, no gameplay advanced.
func _initialize() -> void:
 _seed.call_deferred()
func _seed() -> void:
 var s: GameState=ScenarioLoader.build(Content.db(),"m2a_expedition",70,"normal")
 s.turn=2
 var err: Error=root.get_node("SaveService").call("save","fixture_audit_start",s)
 print("SYNTHETIC normal preview turn2 saveError=%d" % err)
 quit(0 if err==OK else 1)
