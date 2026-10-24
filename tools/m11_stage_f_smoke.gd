extends SceneTree
const OUT: String="res://screens/m11_stage_f"
var checks: T=T.new()
var app: Variant
var probe: Variant
var captures: Array[String]=[]
var tours: Dictionary={}

func _initialize() -> void: _run.call_deferred()
func _frames(count: int=4) -> void:
	for i: int in count: await process_frame

func _until(predicate: Callable, label: String, timeout: int=120) -> void:
	var start: int=Time.get_ticks_msec(); var logged: int=start
	print("Waiting: "+label)
	while not predicate.call() and Time.get_ticks_msec()-start<timeout*1000:
		if label=="integrated terrain completes":
			probe.reveal("PlannerGrid")
			if Time.get_ticks_msec()-logged>10000:
				logged=Time.get_ticks_msec(); print(JSON.stringify({"waiting":label,"seconds":(logged-start)/1000,"metrics":probe.evidence().get("renderer",{}),"scheduler":root.get_node("Worlds").scheduler.metrics()}))
		await process_frame
	checks.ok(predicate.call(),label); print("Ready: "+label+" in "+str(Time.get_ticks_msec()-start)+" ms")

func _ready_city() -> void:
	await _frames()
	probe.reveal("PlannerGrid")
	await _until(func() -> bool: return probe.evidence()["renderer"].has("busy") and not probe.evidence()["renderer"]["busy"],"integrated terrain completes")
	root.get_node("Overlay").call("close_all"); await _frames()

func _click(name: String) -> void:
	var target: Node=app.screen.find_child(name,true,false)
	checks.ok(target!=null,"existing control: "+name)
	if target==null: return
	var button: BaseButton=target as BaseButton
	if button==null:
		for child: Node in target.find_children("*","BaseButton",true,false): button=child as BaseButton; break
	if button==null and target.has_signal("pressed"):
		target.emit_signal("pressed"); await _frames(); return
	checks.ok(button!=null and not button.disabled,"enabled control: "+name)
	if button==null or button.disabled: return
	if button is CheckButton: button.button_pressed=not button.button_pressed
	button.pressed.emit(); await _frames()

func _capture(name: String) -> void:
	root.get_node("Overlay").call("close_all")
	probe.reveal("PlannerGrid"); await _frames(5); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join(name+".png")); captures.append(name+".png"); print("Captured "+name)

func _resolve() -> void:
	probe.perform("resolve"); await _frames(6); root.get_node("Overlay").call("close_all")
	checks.eq(probe.evidence()["state_hash"],probe.expected_hash,"actual turn matches pure M1 replay")

func _tour(mode: String) -> void:
	probe.fixture(); await _frames(6)
	root.get_node("Settings").call("set_appearance",mode); await _frames(6)
	if mode=="3d": await _ready_city()
	var initial: Dictionary=probe.evidence()
	var game: Node=root.get_node("Game")
	var state: GameState=game.call("view")
	var colony: Colony=state.colonies[app.screen.colony_id]
	var free: Array[int]=ColonyRules.free_slots(colony,state.planets[colony.planet_id])
	await _click("Slot_"+str(free[0])); await _click("Option_agriculture")
	if mode=="3d":
		checks.eq(probe.evidence()["renderer"]["terrain_requests"],initial["renderer"]["terrain_requests"],"preview does not bake terrain")
		await _capture("02_placement_preview")
	await _click("Build"); checks.eq(probe.evidence()["queue"].size(),1)
	if mode=="3d":
		checks.eq(probe.evidence()["renderer"]["instance"],initial["renderer"]["instance"])
		checks.eq(probe.evidence()["renderer"]["completed_nodes"],initial["renderer"]["completed_nodes"],"queued construction leaves completed assemblies intact")
		checks.eq(probe.evidence()["renderer"]["terrain_requests"],initial["renderer"]["terrain_requests"])
	await _click("Slot_"+str(free[1])); await _click("Option_energy"); await _click("Build")
	var queue: Array=probe.evidence()["queue"]
	checks.eq(queue.size(),2,"both districts enter the queue")
	if queue.size()!=2: return
	await _click("MoveUp_"+queue[1]["id"])
	checks.eq(probe.evidence()["queue"][0]["id"],queue[1]["id"])
	var head: String=probe.evidence()["queue"][0]["id"]
	var turns: int=probe.evidence()["queue"][0]["turns"]
	await _click("Rush_"+head); checks.eq(probe.evidence()["queue"][0]["turns"],turns-1)
	if mode=="3d": await _capture("03_separate_construction_queue")
	await _click("Cancel_"+head); checks.eq(probe.evidence()["queue"].size(),1)
	await _click("Undo"); checks.eq(probe.evidence()["queue"].size(),2)
	await _click("Cancel_"+head)
	for i: int in 8:
		if probe.evidence()["queue"].is_empty(): break
		await _resolve()
	checks.ok(probe.evidence()["queue"].is_empty())
	if mode=="3d": await _ready_city()
	await _click("Slot_0")
	var before_upgrade: Dictionary=probe.evidence()
	await _click("Upgrade"); checks.eq(probe.evidence()["tiers"]["0"],1,"upgrade remains queued")
	if mode=="3d": checks.eq(probe.evidence()["renderer"]["completed_nodes"],before_upgrade["renderer"]["completed_nodes"])
	for i: int in 8:
		if probe.evidence()["queue"].is_empty(): break
		await _resolve()
	checks.eq(probe.evidence()["tiers"]["0"],2)
	if mode=="3d":
		checks.eq(probe.evidence()["renderer"]["terrain_requests"],before_upgrade["renderer"]["terrain_requests"],"tier change reuses terrain")
		for key: String in before_upgrade["renderer"]["completed_nodes"]:
			if key!="slot:0": checks.eq(probe.evidence()["renderer"]["completed_nodes"][key],before_upgrade["renderer"]["completed_nodes"][key],"upgrade patches only affected assembly")
		await _capture("04_completed_upgrade")
	await _click("Demolish"); checks.not_ok(probe.evidence()["tiers"].has("0"))
	if mode=="3d":
		checks.not_ok(probe.evidence()["renderer"]["completed_nodes"].has("slot:0"),"demolition changes geometry immediately")
		await _ready_city(); await _capture("05_prepared_ground_after_demolition")
	await _click("Undo"); checks.eq(probe.evidence()["tiers"]["0"],2)
	if mode=="3d": await _ready_city()
	checks.eq(probe.evidence()["anchor"],initial["anchor"],"all planner commands preserve geographic anchor")
	tours[mode]={"preview_hash":probe.evidence()["preview_hash"],"state_hash":probe.evidence()["state_hash"],"anchor":probe.evidence()["anchor"]}

func _run() -> void:
	var catcher: Logger=(load("res://tools/m11_stage_c_smoke.gd") as GDScript).ErrorCatcher.new(); OS.add_logger(catcher)
	root.size=Vector2i(1920,1080); root.get_node("Layout").call("set_profile",1)
	DirAccess.make_dir_recursive_absolute(OUT); FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	var save_dir: String="user://stage_f_review"
	if DirAccess.dir_exists_absolute(save_dir):
		for file: String in DirAccess.open(save_dir).get_files(): DirAccess.remove_absolute(save_dir.path_join(file))
	app=(load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(app)
	probe=(load("res://ui/world/stage_f_probe.gd") as GDScript).new(); app.add_child(probe)
	await probe.start(app); await _ready_city()
	if not OS.get_cmdline_user_args().has("--functional-only"): await _finish_review()
	if OS.get_cmdline_user_args().has("--art-only"):
		app.queue_free(); await _frames(5); root.get_node("Worlds").call("restart"); await _frames()
		root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
		for error: String in catcher.call("take"): checks.fail(error)
		OS.remove_logger(catcher)
		FileAccess.open(OUT.path_join("art_verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks.checks,"failures":checks.failures,"captures":captures,"qualification":"Current production renderer at 1920x1080; explicit district/building/planet/spectral/hull fixtures; retained E comparison shares physical profiles and camera."},"\t"))
		print(JSON.stringify({"checks":checks.checks,"failures":checks.failures,"captures":captures.size()})); quit(0 if checks.failures.is_empty() else 1); return
	probe.fixture(); await _ready_city()
	checks.eq(probe.evidence()["renderer"]["tiles"],16)
	checks.ok(app.screen.find_child("Open3DCity",true,false)==null,"normal planner retires study overlay entry")
	await _capture("01_normal_colony_planner")
	var renderer: Variant=app.screen.world_controller.host.renderer
	var completed_pick: Dictionary=renderer.completed.duplicate()
	var queued_pick: Dictionary=renderer.queued.duplicate()
	var blocked_pick: Array=renderer._blocked_pick.duplicate()
	renderer.completed.clear(); renderer.queued.clear(); renderer._blocked_pick.clear()
	for site: Dictionary in renderer.recipe["slots"]:
		var pointer: Vector2=renderer.camera.unproject_position(site["at"])*renderer._container.size/Vector2(renderer.viewport.size)
		checks.eq(renderer.pick_slot(pointer),site["slot"],"canonical hex ray pick")
	renderer.completed.assign(completed_pick); renderer.queued.assign(queued_pick); renderer._blocked_pick.assign(blocked_pick)
	var tallest: Dictionary={}; var height: float=-INF
	for entry: Dictionary in renderer.completed.values():
		if entry["pick"].is_empty(): continue
		for part: Dictionary in entry["pick"]["parts"]:
			var transform: Transform3D=part["transform"]
			var box: AABB=part["bounds"]
			var top: Vector3=transform*(box.position+box.size*Vector3(0.5,0.99,0.5))
			if top.y>height: height=top.y; tallest={"at":top,"slot":entry["pick"]["slot"]}
	var roof_pointer: Vector2=renderer.camera.unproject_position(tallest["at"])*renderer._container.size/Vector2(renderer.viewport.size)
	checks.eq(renderer.pick_slot(roof_pointer),tallest["slot"],"visible roof selects its assembly's parcel")
	# An explicit single-tree cover fixture isolates reversible masks from sparse
	# vegetation placement. Restore the original recipe before any capture.
	var state: GameState=root.get_node("Game").call("view")
	var colony: Colony=state.colonies[app.screen.colony_id]
	var free_slot: int=ColonyRules.free_slots(colony,state.planets[colony.planet_id]).back()
	var original_trees: Array=renderer.recipe["trees"]
	var at: Vector3=renderer.recipe["slots"][free_slot]["at"]
	renderer.recipe["trees"]=[Vector4(at.x,at.y,at.z,1.0)]
	renderer._vegetation()
	var cover_before: int=_cover_count(renderer)
	var original_snapshot: Dictionary=renderer.snapshot.duplicate(true)
	renderer.configure(original_snapshot,{"slot":free_slot,"id":"agriculture","kind":"district","tier":1,"valid":true})
	checks.ok(_cover_count(renderer)<cover_before,"preview masks conflicting vegetation")
	renderer.configure(original_snapshot,{})
	checks.eq(_cover_count(renderer),cover_before,"clearing preview restores cover without terrain work")
	var queued: Dictionary=original_snapshot.duplicate(true)
	queued["queue"].append({"item_id":"cover_fixture","slot":free_slot,"id":"agriculture","kind":"district","tier":1,"turns_left":2,"total_turns":3})
	renderer.configure(queued,{})
	checks.ok(_cover_count(renderer)<cover_before,"queue mask stays separate from completed ground")
	renderer.configure(original_snapshot,{})
	checks.eq(_cover_count(renderer),cover_before,"cancel/Undo snapshot restores vegetation")
	renderer.recipe["trees"]=original_trees; renderer._vegetation()
	var key: InputEventKey=InputEventKey.new(); key.pressed=true; key.keycode=KEY_RIGHT
	renderer._viewport_input(key); await _frames()
	checks.eq(app.screen.slot,0,"keyboard uses the same planner selection")
	key.keycode=KEY_HOME; renderer._viewport_input(key); await _frames()
	checks.eq(app.screen.slot,-1,"Home clears inspector selection and scene highlight together")
	var instance: int=renderer.get_instance_id(); var yaw: float=renderer._yaw
	probe.perform("relayout"); await _frames(8)
	checks.eq(app.screen.world_controller.host.renderer.get_instance_id(),instance)
	checks.eq(app.screen.world_controller.host.renderer._yaw,yaw)
	await _tour("3d"); await _tour("strategic"); checks.eq(tours["3d"],tours["strategic"],"identical planner orders in both presentations")
	root.get_node("Settings").call("set_appearance","3d"); await _ready_city()
	probe.perform("save"); checks.eq(probe.error,"0"); var saved: Dictionary=probe.evidence()
	probe.perform("restore"); await _ready_city()
	checks.eq(probe.evidence()["state_hash"],saved["state_hash"]); checks.eq(probe.evidence()["graphics_hash"],saved["graphics_hash"]); checks.eq(probe.evidence()["prepared"],saved["prepared"])
	await _capture("06_city_after_save_reload")
	var coverage: Array[String]=[]
	for group: int in 4:
		probe.fixture("continental",["ark","meridian","vael","ark"][group],group); await _ready_city()
		var snap: Dictionary=app.screen.world_controller.host.renderer.snapshot
		for building: Dictionary in snap["buildings"]:
			if not coverage.has(building["id"]): coverage.append(building["id"])
		checks.eq(snap["stage"],"city")
		await _capture("07_"+str(group)+"_building_catalog_fixture")
	checks.eq(coverage.size(),15,"all actual building assemblies rendered")
	for kind: String in ["ocean","arid","ice","barren","toxic"]:
		probe.fixture(kind); await _ready_city(); await _capture("08_"+kind+"_terrain_fixture")
		checks.eq(app.screen.world_controller.host.renderer.slot_areas.size(),probe.evidence()["slot_count"])
	var counts: Array[int]=[]
	for size_id: String in ["tiny","small","medium","large","huge"]:
		probe.fixture("continental","ark",-1,5,size_id); await _ready_city()
		counts.append(probe.evidence()["slot_count"])
		checks.eq(app.screen.world_controller.host.renderer.slot_areas.size(),probe.evidence()["slot_count"])
	checks.eq(counts,[12,16,20,25,30],"normal renderer supports every actual base size")
	probe.fixture("continental","ark",-1,4); await _ready_city(); checks.eq(probe.evidence()["stage"],"settlement")
	await _capture("09_settlement_stage_fixture")
	var layouts: Array[Dictionary]=[]
	for compact: bool in [false,true]:
		root.get_node("Layout").call("set_profile",2 if compact else 1)
		root.size=Vector2i(2400,1080) if compact else Vector2i(1920,1080)
		for scale: float in [1.0,2.0]:
			root.get_node("Settings").call("set_text_scale",scale); await _frames(8)
			var audit: IdAudit.AuditReport=IdAudit.run(root,root.get_node("Overlay").get("root"),Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size")),compact)
			checks.eq(audit.issues.size(),0,"normal Colony PC/phone 100/200% audit")
			for chip: Dictionary in probe.evidence()["resource_chips"]: checks.ok(chip["whole"],"resource chip never clips a number")
			checks.ok(not probe.evidence()["resource_chips"].is_empty(),"a complete resource remains visible")
			layouts.append({"phone":compact,"text_scale":scale,"issues":audit.issues,"chips":probe.evidence()["resource_chips"]})
			await _capture("10_"+("phone" if compact else "pc")+"_"+str(int(scale*100)))
	var last: Dictionary=probe.evidence()
	app.queue_free(); await _frames(5); root.get_node("Worlds").call("restart"); await _frames()
	root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
	for error: String in catcher.call("take"): checks.fail(error)
	OS.remove_logger(catcher)
	var result: Dictionary={"checks":checks.checks,"failures":checks.failures,"tours":tours,"saved":saved,"final":last,"building_coverage":coverage,"base_sizes":counts,"layouts":layouts,"captures":captures,"qualification":"Actual native software OpenGL; construction buttons invoke existing UI signals. Family/catalog scenes are explicit fixtures, not naturally progressed campaigns."}
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify({"checks":checks.checks,"failures":checks.failures,"captures":captures.size()})); quit(0 if checks.failures.is_empty() else 1)

func _cover_count(renderer: Variant) -> int:
	var total: int=0
	for child: Node in renderer._vegetation_root.get_children():
		if child is MultiMeshInstance3D: total+=(child as MultiMeshInstance3D).multimesh.instance_count
	return total

func _scene_capture(label: String) -> void:
	# Capture the production scene at 1920x1080, without modifying its rendering.
	var host: Variant=app.screen.world_controller.host
	host.set_process(false); host.position=Vector2.ZERO; host.size=Vector2(1920,1080)
	host.renderer.position=Vector2.ZERO; host.renderer.size=Vector2(1920,1080)
	host.renderer.call("set_active",true,false)
	await _frames(2); await RenderingServer.frame_post_draw
	checks.eq(host.renderer.viewport.get_texture().get_image().save_png(OUT.path_join(label+".png")),OK)
	captures.append(label+".png"); print("Captured "+label)
	host.set_process(true); await _frames(5)

func _finish_review() -> void:
	checks.eq(probe.evidence()["city_kit_version"],3)
	probe.fixture("continental","ark",0); await _ready_city()
	var pinned: Dictionary=probe.evidence()
	probe.perform("legacy_finish"); await _ready_city()
	var renderer: Variant=app.screen.world_controller.host.renderer
	renderer.set_parcel_overlay(false); renderer.select_slot(0,false); renderer._distance=10; renderer._pitch=0.44
	await _scene_capture("finish_01_retained_stage_e_comparison")
	await _click("UpgradeVisualFinish"); await _ready_city()
	checks.eq(probe.evidence()["state_hash"],pinned["state_hash"],"visual upgrade never changes gameplay")
	checks.eq(probe.evidence()["anchor"],pinned["anchor"]); checks.eq(probe.evidence()["prepared"],pinned["prepared"])
	renderer=app.screen.world_controller.host.renderer
	renderer.set_parcel_overlay(false); renderer.select_slot(0,false); renderer._distance=10; renderer._pitch=0.44
	await _scene_capture("finish_02_current_ember_comparison")
	checks.eq(renderer._finish_lod,0,"street view uses authored near geometry")
	await _click("WorldDusk"); await _scene_capture("finish_03_ember_dusk")
	checks.ok(renderer.dusk); await _click("WorldDusk")
	for style: String in ["ark","meridian","vael"]:
		probe.fixture("continental",style,0); await _ready_city()
		for tier: int in [1,2,3]:
			var state: GameState=root.get_node("Game").get("state").clone()
			for district: Colony.PlacedDistrict in state.colonies[app.screen.colony_id].districts: district.tier=tier
			root.get_node("Game").call("resume",state,"","",true); await _ready_city()
			renderer=app.screen.world_controller.host.renderer
			renderer.set_parcel_overlay(false); renderer._target=Vector3(0,renderer.generator.height_at(0,0)+1,0)
			renderer._distance=25; renderer._pitch=0.65; renderer._yaw=0.55
			await _scene_capture("finish_"+style+"_tier_"+str(tier))
	probe.fixture("continental","ark",0); await _ready_city()
	renderer=app.screen.world_controller.host.renderer
	for kind: String in ["agriculture","industry","research"]:
		for site: Dictionary in renderer.recipe["slots"]:
			if site["kind"]!=kind: continue
			renderer.select_slot(site["slot"],false); renderer._distance=9; renderer._pitch=0.42; renderer.set_parcel_overlay(false)
			await _scene_capture("finish_close_"+kind); break
	for building: Dictionary in renderer.snapshot["buildings"]:
		if building["id"] not in ["ark_hull","spaceport"]: continue
		var at: Vector3=renderer._landmark_position(0) if building["id"]=="ark_hull" else renderer.recipe["slots"][building["slot"]]["at"]
		renderer._target=at+Vector3(0,1,0); renderer._distance=19 if building["id"]=="ark_hull" else 9
		await _scene_capture("finish_close_"+building["id"])
	# These are explicit owned-hull fixtures, rendered through the real System view.
	var state: GameState=root.get_node("Game").get("state").clone()
	var colony: Colony=state.colonies[app.screen.colony_id]
	Ships.launch(state,colony,"colony_ship")
	root.get_node("Game").call("resume",state,"","",true); await _frames(6)
	probe.perform("system"); await _frames(6)
	var space: Variant=app.screen.world_controller.host.renderer
	await _scene_capture("finish_space_overview")
	for ship: Ship in state.ships.values():
		if ship.owner_id!=state.player_id: continue
		space.focus_body(ship.id,false); space._yaw=0.65; space._pitch=0.40
		await _scene_capture("finish_hull_"+ship.hull)
	for id: String in ["pl_aster","pl_brume","pl_cinder","pl_dross","pl_tithe","sys_ember"]:
		space.focus_body(id,false)
		if space.bodies[id]["kind"]!="asteroid_belt": await _until(func() -> bool: return space.bodies[id]["width"]>=1024,"focused surface finish")
		await _scene_capture("finish_space_"+space.bodies[id]["kind"])
	# Additional families use named substitutions, never undisclosed foreign data.
	for family: String in ["arid","ice","toxic"]:
		state=root.get_node("Game").get("state").clone(); state.planets["pl_aster"].type=family
		root.get_node("Game").call("resume",state,"","",true); await _frames(8)
		space=app.screen.world_controller.host.renderer; space.focus_body("pl_aster",false)
		await _until(func() -> bool: return space.bodies["pl_aster"]["width"]>=1024,"additional planet family")
		await _scene_capture("finish_space_"+family)
	for family: String in ["M","G","F","A","white_dwarf","binary"]:
		state=root.get_node("Game").get("state").clone(); state.systems["sys_ember"].spectral=family
		root.get_node("Game").call("resume",state,"","",true); await _frames(8)
		space=app.screen.world_controller.host.renderer; space.focus_body("sys_ember",false)
		await _until(func() -> bool: return space.bodies["sys_ember"]["width"]>=1024,"additional spectral family")
		await _scene_capture("finish_star_"+family)
	var key: InputEventKey=InputEventKey.new(); key.pressed=true; key.keycode=KEY_RIGHT
	key.keycode=KEY_HOME; space._viewport_input(key); checks.eq(space.selected_id,"","space Home resets selection")
	await _frames(4); space=app.screen.world_controller.host.renderer
	var before: String=root.get_node("Game").get("state").state_hash()
	key.keycode=KEY_RIGHT; space._viewport_input(key); await _frames(4)
	checks.eq(root.get_node("Game").get("state").state_hash(),before,"space keyboard selection/navigation is cosmetic")
