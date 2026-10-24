extends SceneTree
const OUT: String="res://screens/m11_immersive"
var t: T=T.new()
var app: Variant
var probe: Variant
var captures: Array[String]=[]
var layouts: Array[Dictionary]=[]
var comparisons: Dictionary={}
func _initialize() -> void: run.call_deferred()
func frames(n: int=5) -> void:
	for i: int in n: await process_frame
func city_ready() -> void:
	await frames()
	var start: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<120000:
		probe.reveal("PlannerGrid"); await frames(2)
		if probe.evidence().get("renderer",{}).get("busy",true)==false: return
	t.fail("city refinement did not complete")
func click(name_value: String) -> void:
	var node: Node=app.screen.find_child(name_value,true,false)
	if node==null: node=root.get_node("Overlay").get("root").find_child(name_value,true,false)
	t.ok(node!=null,"control exists: "+name_value)
	if node==null: return
	var button: BaseButton=node as BaseButton
	if button==null:
		for child: Node in node.find_children("*","BaseButton",true,false): button=child as BaseButton; break
	t.ok(button!=null and not button.disabled,"control enabled: "+name_value)
	if button==null or button.disabled: return
	button.pressed.emit(); await frames(); print("Pressed "+name_value+"; queue "+str(probe.evidence()["queue"].size()))
func capture(label: String) -> void:
	await frames(); await RenderingServer.frame_post_draw
	t.eq(root.get_texture().get_image().save_png(OUT.path_join(label+".png")),OK,"capture "+label)
	captures.append(label+".png")
func audit(label: String) -> void:
	await frames(8)
	var view: Rect2=Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size"))
	var result: IdAudit.AuditReport=IdAudit.run(root,root.get_node("Overlay").get("root"),view,root.get_node("Layout").get("touch_ui"))
	t.eq(result.issues.size(),0,"layout "+label)
	var panel: Control=app.screen.find_child("ImmersiveContext",true,false)
	if panel!=null:
		t.ok(app.screen._scroll.get_global_rect().encloses(panel.get_global_rect()),"context fits visible map "+label)
		if app.screen.immersive_panel=="tools":
			var quality: BaseButton=app.screen.find_child("Quality_standard",true,false)
			var scroll: ScrollContainer=app.screen.find_child("ImmersiveContextScroll",true,false)
			scroll.ensure_control_visible(quality); await frames(5)
			var point: Vector2=quality.get_global_rect().get_center()
			t.ok(view.has_point(point) and scroll.get_global_rect().has_point(point) and panel.get_global_rect().has_point(point),"quality reachable inside clipped panel "+label)
	var host: Variant=app.screen.world_controller.host
	var area: float=host.size.x*host.size.y/(view.size.x*view.size.y)
	if app.screen._immersive_layout: t.ok(area>0.65,"world dominates "+label)
	for name_value: String in ["ModeToggle","Nav_more","Undo","EndTurn"]:
		var control: Control=app.screen.find_child(name_value,true,false)
		if control!=null: t.ok(view.encloses(control.get_global_rect()),"reachable "+name_value)
	layouts.append({"label":label,"issues":result.issues,"viewport_share":area,"logical":str(view.size)})
	print(JSON.stringify(layouts.back()))
func actual_drag(middle: bool=false) -> void:
	var renderer: Variant=app.screen.world_controller.host.renderer
	var point: Vector2=renderer.global_position+renderer.size*Vector2(0.1,0.1)
	var before: Dictionary=renderer.camera_state()
	var move: InputEventMouseMotion=InputEventMouseMotion.new(); move.position=point; move.global_position=point
	root.push_input(move,true); await frames(2)
	var press: InputEventMouseButton=InputEventMouseButton.new(); press.position=point; press.global_position=point
	press.button_index=MOUSE_BUTTON_MIDDLE if middle else MOUSE_BUTTON_LEFT; press.pressed=true
	press.button_mask=MOUSE_BUTTON_MASK_MIDDLE if middle else MOUSE_BUTTON_MASK_LEFT
	root.push_input(press,true); await frames(2); print("Drag held: ",renderer._dragging," pan ",renderer._panning," tooltip ",renderer._container.tooltip_text)
	move=InputEventMouseMotion.new(); move.position=point+Vector2(90,20); move.global_position=move.position; move.relative=Vector2(90,20)
	move.button_mask=MOUSE_BUTTON_MASK_MIDDLE if middle else MOUSE_BUTTON_MASK_LEFT
	root.push_input(move,true); await frames(2)
	press.pressed=false; press.button_mask=0; press.position=move.position; press.global_position=move.position
	root.push_input(press,true); await frames()
	print("GUI drag "+str(renderer.get_class())+" "+str(app.screen.view)+" pan="+str(middle)+" before="+str(before)+" after="+str(renderer.camera_state()))
	t.ok(renderer.camera_state()["target"]!=before["target"] if middle else renderer.camera_state()["yaw"]!=before["yaw"],"real GUI drag reaches renderer "+str(app.screen.view)+": "+str(middle))
func tour(mode: String) -> void:
	print("Tour "+mode)
	root.get_node("Settings").call("set_view_mode",mode); probe.fixture(); await city_ready()
	var state: GameState=root.get_node("Game").call("view")
	var colony: Colony=state.colonies[app.screen.colony_id]
	var free: Array[int]=ColonyRules.free_slots(colony,state.planets[colony.planet_id])
	if mode=="immersive": await click("ImmersiveObjects")
	if mode=="immersive": await click("Slot_"+str(free[0]))
	else: await click("Slot_"+str(free[0]))
	await click("Option_agriculture"); await click("Build")
	t.eq(probe.evidence()["queue"].size(),1,"construction in "+mode)
	if probe.evidence()["queue"].is_empty(): return
	var item: String=probe.evidence()["queue"][0]["id"]
	await click("Rush_"+item); await click("Cancel_"+item); await click("Undo")
	t.eq(probe.evidence()["queue"].size(),1,"cancel/Undo in "+mode)
	for i: int in 8:
		if probe.evidence()["queue"].is_empty(): break
		probe.perform("resolve"); await frames(8)
		t.eq(probe.evidence()["state_hash"],probe.expected_hash,"turn agrees with pure simulation")
	await city_ready()
	if mode=="immersive": await click("ImmersiveObjects")
	await click("Slot_0"); await click("Upgrade")
	for i: int in 8:
		if probe.evidence()["queue"].is_empty(): break
		probe.perform("resolve"); await frames(8)
	await city_ready(); t.eq(probe.evidence()["tiers"]["0"],2,"upgrade in "+mode)
	await click("Demolish"); await click("Undo")
	comparisons[mode]={"game":root.get_node("Game").call("view").state_hash(),"prepared":probe.evidence()["prepared"],"anchor":probe.evidence()["anchor"]}
func run() -> void:
	var catcher: Logger=(load("res://tools/m11_stage_c_smoke.gd") as GDScript).ErrorCatcher.new(); OS.add_logger(catcher)
	root.size=Vector2i(1920,1080); root.get_node("Layout").call("set_profile",1)
	DirAccess.make_dir_recursive_absolute(OUT); FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	app=(load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(app)
	probe=(load("res://ui/world/stage_f_probe.gd") as GDScript).new(); probe.review_save_dir="user://immersive_review"; app.add_child(probe)
	await probe.start(app); root.get_node("Settings").call("set_view_mode","command"); probe.fixture(); await city_ready()
	# Fixture setup creates a deferred opening report on an already-restored session.
	# Dismiss it before comparing the layouts or injecting real map input.
	root.get_node("Overlay").call("close_all"); await frames(3); t.eq(root.get_node("Overlay").call("stack_size"),0,"comparison starts without a modal")
	if OS.get_cmdline_user_args().has("--layouts-only"):
		root.get_node("Settings").call("set_view_mode","immersive"); await frames(8)
		await layout_tour()
		app.queue_free(); await frames(5); root.get_node("Worlds").call("restart"); await frames()
		root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
		for error: String in catcher.call("take"): t.fail(error)
		OS.remove_logger(catcher)
		var result: Dictionary={"checks":t.checks,"failures":t.failures,"captures":captures,"layouts":layouts,"qualification":"Final compact toolbar/panel layout at PC, phone landscape and portrait; 100/200% text, Low renderer, actual native software OpenGL."}
		FileAccess.open(OUT.path_join("layouts_verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print(JSON.stringify(result)); quit(0 if t.failures.is_empty() else 1); return
	await capture("01_command_city")
	var before: Dictionary=probe.evidence(); var renderer: Variant=app.screen.world_controller.host.renderer; var camera: Dictionary=renderer.camera_state()
	await click("ModeToggle"); await frames(8)
	t.eq(app.screen.world_controller.host.renderer.get_instance_id(),renderer.get_instance_id(),"mode switch retains renderer")
	t.eq(renderer.camera_state(),camera,"mode switch retains camera")
	for key: String in ["state_hash","graphics_hash","anchor","prepared"]: t.eq(probe.evidence()[key],before[key],"mode switch preserves "+key)
	await audit("desktop immersive overview"); await capture("02_immersive_city")
	root.get_node("Settings").call("set_visual_quality","low"); await city_ready()
	await actual_drag(); await actual_drag(true)
	await click("ImmersiveObjects"); await click("Slot_8"); await capture("03_immersive_parcel_context"); await audit("desktop parcel context")
	await click("ImmersiveClose"); t.not_ok(app.screen.immersive_panel_open,"panel closes")
	await click("ImmersiveManage"); await audit("desktop management"); await capture("04_immersive_management")
	await click("Manage_research"); t.eq(app.screen.view,"research"); t.not_ok(app.screen._immersive_layout,"research uses readable management screen")
	app.screen.show_view("colony"); await frames(8); t.ok(app.screen._immersive_layout,"return restores immersive preference")
	root.get_node("Settings").call("set_visual_quality","low"); await city_ready()
	await tour("command"); await tour("immersive"); t.eq(comparisons["command"],comparisons.get("immersive",{}),"both modes give identical gameplay and geography")
	probe.perform("save"); t.eq(probe.error,"0"); var saved: Dictionary=probe.evidence(); probe.perform("restore"); await city_ready()
	t.ok(app.screen._immersive_layout,"save/load keeps device mode")
	for key: String in ["state_hash","graphics_hash","anchor","prepared"]: t.eq(probe.evidence()[key],saved[key],"save/load preserves "+key)
	await capture("05_immersive_after_reload")
	root.get_node("Settings").call("set_visual_quality","standard")
	probe.fixture("continental","ark",2); await city_ready()
	app.screen.world_controller.host.renderer.set_dusk(true); app.screen.world_controller.host.renderer.set_parcel_overlay(false)
	app.screen.close_immersive_panel(); await capture("immersive_developed_city_dusk")
	app.screen.close_immersive_panel(); app.screen.show_view("system"); await frames(10)
	await audit("desktop immersive system"); await capture("06_immersive_system")
	await actual_drag(); await actual_drag(true)
	app.screen.open_planet("pl_brume"); await frames(8); app.screen.toggle_immersive_panel("inspect"); await audit("desktop planet commands")
	var probe_id: String=""
	for ship: Ship in root.get_node("Game").call("view").ships_of(app.screen.state.player_id):
		if Ships.role(ship)==Ships.ROLE_SURVEY: probe_id=ship.id
	await click("Survey_"+probe_id); t.ok(root.get_node("Game").call("view").ships[probe_id].is_busy(),"real survey from immersive inspector")
	await capture("07_immersive_planet_commands")
	app.screen.close_immersive_panel(); app.screen.show_view("galaxy"); await frames(8)
	await audit("desktop immersive galaxy"); await capture("08_immersive_galaxy")
	await layout_tour()
	app.queue_free(); await frames(5); root.get_node("Worlds").call("restart"); await frames(); root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
	for error: String in catcher.call("take"): t.fail(error)
	OS.remove_logger(catcher)
	var result: Dictionary={"checks":t.checks,"failures":t.failures,"captures":captures,"layouts":layouts,"comparisons":comparisons,"saved":saved,"qualification":"Native software OpenGL; real GUI orbit/pan, shared inspector command signals, progressed fixtures and PC/touch-sized layouts. Physical devices and Stage G remain pending."}
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print(JSON.stringify({"checks":t.checks,"failures":t.failures,"captures":captures.size()})); quit(0 if t.failures.is_empty() else 1)

func layout_tour() -> void:
	root.get_node("Settings").call("set_visual_quality","low"); await frames(8)
	for profile: Array in [[Vector2i(1920,1080),1,"desktop"],[Vector2i(2400,1080),2,"phone_landscape"],[Vector2i(1072,2300),2,"phone_portrait"]]:
		root.get_node("Layout").call("set_profile",profile[1]); root.size=profile[0]
		for scale: float in [1.0,2.0]:
			root.get_node("Settings").call("set_text_scale",scale); probe.fixture(); await city_ready(); app.screen.close_immersive_panel()
			await audit(profile[2]+" overview "+str(scale)); await capture(profile[2]+"_overview_"+str(int(scale*100)))
			app.screen.select_slot(8); await audit(profile[2]+" context "+str(scale)); await capture(profile[2]+"_context_"+str(int(scale*100)))
			app.screen.toggle_immersive_panel("manage"); await audit(profile[2]+" manage "+str(scale))
			app.screen.toggle_immersive_panel("tools"); await audit(profile[2]+" tools "+str(scale))
			app.screen.close_immersive_panel()
