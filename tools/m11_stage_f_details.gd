extends SceneTree
const OUT: String="res://screens/m11_stage_f_details"
var t: T=T.new()
var app: Variant
var probe: Variant
var captures: Array[String]=[]

func _initialize() -> void: _run.call_deferred()
func frames(count: int=4) -> void:
	for i: int in count: await process_frame
func ready_city() -> void:
	var start: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<120000:
		probe.reveal("PlannerGrid"); await frames(2)
		if probe.evidence().get("renderer",{}).get("busy",true)==false: return
	t.fail("city did not complete")
func capture(label: String) -> void:
	var host: Variant=app.screen.world_controller.host
	host.set_process(false); host.position=Vector2.ZERO; host.size=Vector2(1920,1080)
	host.renderer.position=Vector2.ZERO; host.renderer.size=Vector2(1920,1080); host.renderer.call("set_active",true,false)
	await frames(2); await RenderingServer.frame_post_draw
	t.eq(host.renderer.viewport.get_texture().get_image().save_png(OUT.path_join(label+".png")),OK)
	captures.append(label+".png"); host.set_process(true); await frames()

func _run() -> void:
	var catcher: Logger=(load("res://tools/m11_stage_c_smoke.gd") as GDScript).ErrorCatcher.new(); OS.add_logger(catcher)
	root.size=Vector2i(1920,1080); root.get_node("Layout").call("set_profile",1)
	DirAccess.make_dir_recursive_absolute(OUT); FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
	app=(load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(app)
	probe=(load("res://ui/world/stage_f_probe.gd") as GDScript).new(); app.add_child(probe); await probe.start(app)
	probe.fixture("continental","ark",2); await ready_city()
	var city: Variant=app.screen.world_controller.host.renderer
	var finished_ground: bool=false
	for node: Node in city._landscape.get_children():
		if node is MeshInstance3D and node.material_override is ShaderMaterial:
			var material: ShaderMaterial=node.material_override
			if material.shader.resource_path!="res://ui/art/shaders/ground.gdshader": continue
			finished_ground=true
			for family: String in ["soil","rock"]:
				for channel: String in ["albedo","normal","roughness"]:
					t.ok(material.get_shader_parameter(family+"_"+channel) is Texture2D,"regional finish map is bound")
	t.ok(finished_ground,"normal playable regional mesh uses the finished shader")
	var found: bool=false
	for building: Dictionary in city.snapshot["buildings"]:
		if building["id"]!="spaceport": continue
		found=true; city.select_slot(building["slot"],false); city._distance=9; city._pitch=0.43; city.set_parcel_overlay(false)
		await capture("spaceport_close")
	t.ok(found,"actual spaceport catalog fixture rendered")
	var state: GameState=root.get_node("Game").get("state").clone()
	var outpost: Colony=Colony.new(); outpost.id="review_outpost"; outpost.owner_id=state.player_id; outpost.planet_id="pl_tithe"; outpost.outpost_kind="minerals"
	state.colonies[outpost.id]=outpost; state.planets[outpost.planet_id].colony_id=outpost.id
	root.get_node("Game").call("resume",state,"","",true); await frames(6); probe.perform("system"); await frames(6)
	var space: Variant=app.screen.world_controller.host.renderer
	t.ok(space.bodies.has(outpost.id),"owned facility crosses normal snapshot boundary")
	space.focus_body(outpost.id,false); space._yaw=0.65; await capture("owned_outpost_close")
	probe.fixture(); await ready_city(); city=app.screen.world_controller.host.renderer
	root.get_node("Settings").call("set_reduce_motion",false); city.motion_paused=false; await frames(6)
	var clock: float=city.visual_time; city.motion_paused=true; await frames(6); t.eq(city.visual_time,clock,"Pause holds all shared city clocks")
	city.motion_paused=false; root.get_node("Settings").call("set_reduce_motion",true); await frames(6); t.eq(city.visual_time,clock,"Reduced motion holds city clocks")
	city.select_slot(0,false); root.get_node("Settings").call("set_high_contrast",true); await frames(); await capture("high_contrast_selection")
	root.get_node("Settings").call("set_high_contrast",false)
	var layouts: Array[Dictionary]=[]
	root.get_node("Layout").call("set_profile",2); root.size=Vector2i(1072,2300)
	for scale: float in [1.0,2.0]:
		root.get_node("Settings").call("set_text_scale",scale); await frames(8)
		var report: IdAudit.AuditReport=IdAudit.run(root,root.get_node("Overlay").get("root"),Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size")),true)
		t.eq(report.issues.size(),0,"portrait structural audit")
		for chip: Dictionary in probe.evidence()["resource_chips"]: t.ok(chip["whole"],"portrait resource value is whole")
		app.screen._top.open_more(); await frames(8); await RenderingServer.frame_post_draw
		var drawer_report: IdAudit.AuditReport=IdAudit.run(root,root.get_node("Overlay").get("root"),Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size")),true)
		t.eq(drawer_report.issues.size(),0,"portrait resource drawer structural audit")
		var name: String="portrait_resource_drawer_"+str(int(scale*100))+".png"
		root.get_texture().get_image().save_png(OUT.path_join(name)); captures.append(name)
		layouts.append({"text_scale":scale,"issues":report.issues,"drawer_issues":drawer_report.issues,"chips":probe.evidence()["resource_chips"]}); root.get_node("Overlay").call("close_all")
		var original_hash: String=root.get_node("Game").get("state").state_hash()
		var more: BaseButton=app.screen.find_child("Nav_more",true,false)
		t.ok(Rect2(Vector2.ZERO,root.get_node("Layout").get("logical_size")).encloses(more.get_global_rect()),"portrait navigation drawer stays reachable")
		more.pressed.emit(); await frames()
		var switch: BaseButton=root.get_node("Overlay").get("root").find_child("More_system",true,false)
		t.ok(switch!=null,"System remains accessible after collapsing portrait tabs")
		if switch!=null: switch.pressed.emit(); await frames(6)
		t.eq(app.screen.view,"system"); t.eq(root.get_node("Game").get("state").state_hash(),original_hash)
		app.screen.find_child("Nav_more",true,false).pressed.emit(); await frames()
		var back: BaseButton=root.get_node("Overlay").get("root").find_child("More_colony",true,false)
		t.ok(back!=null,"Colony remains accessible in portrait navigation")
		if back!=null: back.pressed.emit(); await ready_city()
	app.queue_free(); await frames(5); root.get_node("Worlds").call("restart"); await frames(); root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
	for error: String in catcher.call("take"): t.fail(error)
	OS.remove_logger(catcher)
	var result: Dictionary={"checks":t.checks,"failures":t.failures,"captures":captures,"layouts":layouts,"qualification":"Production spaceport/owned-outpost fixtures, shared Pause/Reduced-motion clocks, high-contrast and portrait resource drawer; software OpenGL, not physical-device certification."}
	FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print(JSON.stringify(result)); quit(0 if t.failures.is_empty() else 1)
