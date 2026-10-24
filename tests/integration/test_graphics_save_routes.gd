extends RefCounted

func test_all_player_load_routes_restore_saved_graphics(t: T) -> void:
 var tree: SceneTree = Engine.get_main_loop() as SceneTree
 Settings.persist = false; Settings.set_hints_enabled(false); Settings.set_appearance("strategic")
 var old_dir: String = SaveService.dir
 var scratch: String = "user://stage_d_routes_%d" % Time.get_ticks_usec()
 SaveService.dir = scratch
 var state: GameState = ScenarioLoader.build(Content.db(),"s1_first_light",11); state.turn=5
 Game.resume(state,"","",true)
 var expected: Dictionary = Worlds.appearances.data.duplicate(true)
 expected["anchors"][state.colonies_of(state.player_id)[0].id]["heading_mdeg"] = 123456
 Game.resume(state,PresentationEnvelope.pack(expected))
 t.eq(SaveService.save("manual_1",state),OK)
 t.eq(SaveService.save("checkpoint_1",state),OK)
 var app: AppRoot = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
 tree.root.add_child(app); await tree.process_frame; await tree.process_frame
 # Continue uses TitleScreen's cached load result, rather than rereading state only.
 Game.resume(state)
 (app.screen.find_child("Continue",true,false) as BaseButton).pressed.emit()
 await tree.process_frame; await tree.process_frame
 t.eq(Worlds.appearances.data,expected,"Title Continue restores profiles/anchors")
 app.go(AppRoot.LOAD); await tree.process_frame
 Game.resume(state)
 (app.screen as LoadScreen)._load("manual_1")
 await tree.process_frame; await tree.process_frame
 t.eq(Worlds.appearances.data,expected,"Load screen restores presentation")
 # An explicit loss fixture opens the existing checkpoint recovery route.
 var lost: GameState = GameState.from_dict(state.to_dict())
 lost.outcome="loss"; lost.outcome_turn=10; lost.turn=10
 Game.resume(lost); app.go(AppRoot.DEBRIEF); await tree.process_frame
 var debrief: DebriefScreen = app.screen as DebriefScreen
 debrief.set("_checkpoint","checkpoint_1")
 debrief._load_checkpoint(); await tree.process_frame; await tree.process_frame
 t.eq(Worlds.appearances.data,expected,"debrief checkpoint retains appearance")
 t.eq(Game.state.state_hash(),state.state_hash(),"all routes keep the gameplay checksum")
 app.queue_free(); await tree.process_frame; await tree.process_frame
 Overlay.close_all()
 for file: String in DirAccess.open(scratch).get_files(): DirAccess.remove_absolute(scratch.path_join(file))
 DirAccess.remove_absolute(scratch); SaveService.dir = old_dir
