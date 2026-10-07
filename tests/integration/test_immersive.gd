extends RefCounted

func test_mode_setting_roundtrips_and_old_or_future_preferences_fall_back(t: T) -> void:
	var path: String="user://test_immersive_settings.cfg"
	var script: GDScript=load("res://app/settings.gd")
	var settings: Node=script.new()
	settings.persist=false
	settings.set_view_mode("immersive"); settings.set_visual_quality("low")
	settings._save(path)
	var reader: Node=script.new(); reader.persist=false; reader._load(path)
	t.eq(reader.view_mode,"immersive"); t.eq(reader.visual_quality,"low","layout does not force quality")
	var cfg: ConfigFile=ConfigFile.new(); cfg.set_value("display","visual_quality","standard"); cfg.save(path)
	reader._load(path); t.eq(reader.view_mode,"command","settings written before the new toggle default to Command")
	cfg.set_value("display","view_mode","future-layout"); cfg.save(path); reader._load(path)
	t.eq(reader.view_mode,"command","unknown layout falls back without failing settings load")
	t.eq(reader.visual_quality,"standard")
	reader.set_view_mode("invalid"); t.eq(reader.view_mode,"command")
	DirAccess.remove_absolute(path); settings.free(); reader.free()

func test_switching_keeps_renderer_selection_camera_orders_and_saved_world(t: T) -> void:
	var tree: SceneTree=Engine.get_main_loop()
	ImmersiveWorkspace.reset_memory()
	Settings.persist=false; Settings.set_hints_enabled(false); Settings.set_reduce_motion(true)
	Settings.set_appearance("3d"); Settings.set_view_mode("command")
	Game.new_game("s1_first_light",11); GameScreen._opened_seed=11
	var screen: GameScreen=GameScreen.new(); tree.root.add_child(screen)
	await frames()
	var colony: Colony=Game.view().colonies[screen.colony_id]
	var free: Array[int]=ColonyRules.free_slots(colony,Game.view().planets[colony.planet_id])
	screen.select_slot(free[0]); screen.set_pick("district","agriculture")
	var result: Result=screen.order(PlaceDistrictCommand.create(Game.view().player_id,colony.id,free[0],"agriculture"))
	t.ok(result.ok); await frames()
	var before: String=Game.view().state_hash()
	var graphics: String=CanonicalJson.stringify(Worlds.save_fields(Game.state))
	var count: int=screen.order_count()
	for kind: String in ["colony","system","galaxy"]:
		screen.show_view(kind); await frames()
		var renderer: Control=screen.world_controller.host.renderer
		var identity: int=renderer.get_instance_id()
		renderer.set("_yaw",0.89)
		var camera: Dictionary=renderer.call("camera_state")
		for mode: String in ["immersive","command","immersive","command"]:
			Settings.set_view_mode(mode); await frames()
			t.eq(screen.world_controller.host.renderer.get_instance_id(),identity,"same renderer "+kind+" "+mode)
			t.eq(renderer.call("camera_state"),camera,"same camera "+kind+" "+mode)
			t.eq(Game.view().state_hash(),before,"layout is not an order")
			t.eq(screen.order_count(),count,"pending orders survive")
			if mode=="immersive":
				if kind=="colony":
					t.ok(screen.find_child("ImmersiveContext",true,false)!=null,"selection inspector is open on the map")
					t.ok(screen.find_child("ImmersiveWindow_summary",true,false)!=null,"compact summary stays beside the selection inspector")
				screen.toggle_immersive_panel("tools"); await frames()
				t.ok(screen.find_child("ImmersiveContext",true,false)!=null)
				screen.close_immersive_panel(); await frames()
				t.eq(renderer.call("camera_state"),camera,"panels do not reset camera")
	# Navigation may lazily materialise other bodies' profiles; compare only layout
	# switches on the now materialised world, not a pre-navigation graphics snapshot.
	graphics=CanonicalJson.stringify(Worlds.save_fields(Game.state)); Settings.set_view_mode("immersive"); await frames()
	t.eq(CanonicalJson.stringify(Worlds.save_fields(Game.state)),graphics,"mode is absent from saved graphics transport")
	var keyboard: InputEventKey=InputEventKey.new(); keyboard.keycode=KEY_F10; keyboard.pressed=true
	screen.world_controller.host.renderer.get("_container").grab_focus()
	tree.root.push_input(keyboard,true); await frames()
	t.eq(Settings.view_mode,"command","F10 reaches the screen from a focused map")
	tree.root.push_input(keyboard,true); await frames()
	t.eq(Settings.view_mode,"immersive")
	screen.toggle_immersive_panel("tools"); await frames()
	keyboard.keycode=KEY_ESCAPE; tree.root.push_input(keyboard,true); await frames()
	t.ok(screen.immersive_panel_open,"Escape closes only the active window while other desktop windows remain open")
	t.eq(screen.find_child("ImmersiveContext",true,false).name,"ImmersiveContext","another open window becomes active")
	t.eq(Overlay.stack_size(),0,"closing a context does not also open a menu")
	screen.show_view("research"); await frames(); t.ok(screen._immersive_layout)
	t.ok(screen.find_child("ImmersiveContext",true,false)!=null,"research opens in a workspace window")
	screen.show_view("colony"); await frames(); t.ok(screen._immersive_layout)
	screen.world_controller.host.fail_presentation(); await frames()
	t.not_ok(screen._immersive_layout,"Strategic remains a readable fallback")
	t.eq(Settings.view_mode,"immersive","fallback keeps layout preference")
	t.eq(Game.view().state_hash(),before)
	Settings.set_appearance("3d"); await frames(); t.ok(screen._immersive_layout)
	screen.world_controller.host.renderer.set("_distance",9.0)
	Settings.set_visual_quality("low" if Settings.visual_quality != "low" else "standard")
	await frames()
	t.ok(screen.world_controller.host.renderer is ColonyRenderer,"quality change recreates the selected city while terrain is asynchronous")
	t.eq(Game.view().state_hash(),before,"asynchronous quality transition retains gameplay")
	t.eq(Settings.view_mode,"immersive")
	screen.queue_free(); Overlay.close_all(); await frames(); Worlds.restart()
	Settings.set_view_mode("command"); Settings.set_appearance("strategic")

func frames() -> void:
	for i: int in 5: await Engine.get_main_loop().process_frame

func test_compact_windows_keep_real_jobs_and_finish_changes_do_not_mutate_campaign(t: T) -> void:
	var tree: SceneTree=Engine.get_main_loop()
	Settings.persist=false; Settings.set_hints_enabled(false); Settings.set_reduce_motion(true)
	Settings.set_appearance("3d"); Settings.set_view_mode("immersive")
	ImmersiveWorkspace.reset_memory()
	Game.new_game("s1_first_light",11); GameScreen._opened_seed=11
	var screen: GameScreen=GameScreen.new(); tree.root.add_child(screen); await frames()
	var workspace: Variant=screen.find_child("ImmersiveWorld",true,false)
	t.eq(workspace.layout_data["open"],["summary"])
	t.ok(screen.find_child("ImmersiveQueue",true,false)!=null)
	t.ok(screen.find_child("EndTurn",true,false)!=null)
	screen.toggle_immersive_panel("manage"); await frames()
	(screen.find_child("ManageTab_jobs",true,false) as BaseButton).pressed.emit(); await frames()
	t.ok(screen.find_child("JobPriority",true,false)!=null)
	var before_orders: int=screen.order_count()
	(screen.find_child("Raise_energy",true,false) as BaseButton).pressed.emit(); await frames()
	t.eq(screen.order_count(),before_orders+1,"tabbed jobs use the existing simulation order path")
	var hash: String=Game.view().state_hash()
	var fields: String=CanonicalJson.stringify(Worlds.save_fields(Game.state))
	var renderer: int=screen.world_controller.host.renderer.get_instance_id()
	for finish: String in ["matte","glossy","frosted"]:
		Settings.set_interface_finish(finish); await frames()
		t.eq(screen.world_controller.host.renderer.get_instance_id(),renderer,"finish changes retain the renderer")
		t.eq(Game.view().state_hash(),hash,"finish is absent from simulation")
		t.eq(CanonicalJson.stringify(Worlds.save_fields(Game.state)),fields,"finish is absent from saved graphics authority")
	screen.queue_free(); await frames(); Worlds.restart()
	Settings.set_view_mode("command"); Settings.set_appearance("strategic"); ImmersiveWorkspace.reset_memory()

func test_phone_contexts_fit_visible_map_and_scroll_to_quality_at_large_text(t: T) -> void:
	var tree: SceneTree=Engine.get_main_loop()
	ImmersiveWorkspace.reset_memory()
	var original_size: Vector2i=tree.root.size
	var original_profile: int=Layout.profile
	var original_text: float=Settings.text_scale
	Settings.persist=false; Settings.set_hints_enabled(false); Settings.set_reduce_motion(true)
	Settings.set_appearance("3d"); Settings.set_visual_quality("low"); Settings.set_view_mode("immersive")
	Game.new_game("s1_first_light",11); GameScreen._opened_seed=11
	var screen: GameScreen=GameScreen.new(); tree.root.add_child(screen); await frames()
	for window_size: Vector2i in [Vector2i(2400,1080),Vector2i(1072,2300)]:
		tree.root.size=window_size; Layout.set_profile(Layout.Profile.PHONE); await frames()
		for text: float in [1.0,2.0]:
			Settings.set_text_scale(text); await frames()
			for kind: String in ["inspect","manage","tools"]:
				screen.close_immersive_panel(); screen.toggle_immersive_panel(kind); await frames()
				var context: Control=screen.find_child("ImmersiveContext",true,false)
				t.ok(screen._scroll.get_global_rect().encloses(context.get_global_rect()),"context stays inside visible map: "+str(window_size)+" "+str(text)+" "+kind)
				if kind=="tools":
					var quality: BaseButton=screen.find_child("Quality_standard",true,false)
					var scroll: Node=quality
					while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
					t.ok(scroll is ScrollContainer,"window content remains inside its scroll area")
					if scroll is ScrollContainer: (scroll as ScrollContainer).ensure_control_visible(quality)
					await frames()
					t.ok(M11ImmersiveProbe._button_evidence(quality)["reachable"],"quality scrolls into the clipped context at both phone orientations/text sizes")
	screen.queue_free(); await frames(); Worlds.restart()
	Settings.set_text_scale(original_text); Settings.set_view_mode("command"); Settings.set_appearance("strategic")
	tree.root.size=original_size; Layout.set_profile(original_profile); await frames()
