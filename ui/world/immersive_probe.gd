class_name M11ImmersiveProbe
extends M11StageFProbe
## Explicit opt-in browser evidence route; isolated saves and read-only telemetry.
func _init() -> void: review_save_dir="user://immersive_review_web"

func start(owner: AppRoot) -> void:
	Settings.persist=false
	await super(owner)

func perform(request: String) -> void:
	var screen: GameScreen=app.screen as GameScreen
	match request:
		"mode_immersive": Settings.set_view_mode("immersive")
		"mode_command": Settings.set_view_mode("command")
		"context_close": screen.close_immersive_panel()
		"manage": screen.toggle_immersive_panel("manage")
		"objects": screen.toggle_immersive_panel("objects")
		"tools": screen.toggle_immersive_panel("tools")
		"research": screen.show_view("research")
		"finish_matte": Settings.set_interface_finish("matte")
		"finish_frosted": Settings.set_interface_finish("frosted")
		"finish_glossy": Settings.set_interface_finish("glossy")
		"persist_mode": Settings._save()
		_: super(request); return
	serial+=1; _publish()

func reveal(control: String) -> void:
	var target: Control=app.screen.find_child(control,true,false) as Control
	if target==null: target=Overlay.root.find_child(control,true,false) as Control
	if target==null: return
	var parent: Node=target.get_parent()
	while parent!=null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(target); return
		parent=parent.get_parent()

func evidence() -> Dictionary:
	var result: Dictionary=super()
	if result.is_empty(): return result
	var screen: GameScreen=app.screen as GameScreen
	result["view_mode"]=Settings.view_mode
	result["immersive_active"]=screen._immersive_layout
	result["panel_open"]=screen.immersive_panel_open
	result["panel_kind"]=screen.immersive_panel
	result["orders"]=screen.order_count()
	result["interface_finish"]=Settings.interface_finish
	result["workspace"]={}
	var workspace: Variant=screen.find_child("ImmersiveWorld",true,false)
	if workspace!=null:
		var windows: Array=[]
		for kind: String in workspace.panels:
			var window: Control=workspace.panels[kind]
			if not window.is_visible_in_tree(): continue
			var rect: Rect2=window.get_global_rect()
			windows.append({"kind":kind,"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y})
		result["workspace"]={"windows":windows,"active":workspace.layout_data.get("active",""),"manage_tab":workspace.layout_data.get("manage_tab","overview")}
	if host_is_system(screen):
		var system: M1SystemRenderer=screen.world_controller.host.renderer
		var positions: Dictionary={}
		for planet: Dictionary in system.snapshot["planets"]:
			var position: Vector3=system.bodies[planet["id"]]["node"].position
			positions[planet["id"]]={"x":position.x,"z":position.z}
		result["orbit_positions"]=positions
		var outer: float=0.0
		for record: Dictionary in system._display_orbital.get("bodies",{}).values(): outer=maxf(outer,float(record["display_milli"])/1000.0)
		if outer>0:
			var frame: Rect2=Rect2(system.camera.unproject_position(Vector3(outer,0,0)),Vector2.ZERO)
			for point: Vector3 in OrbitalLayout.path_mesh(outer): frame=frame.expand(system.camera.unproject_position(point))
			result["orbit_frame"]={"x":frame.position.x,"y":frame.position.y,"width":frame.size.x,"height":frame.size.y,"scene_width":system.viewport.size.x,"scene_height":system.viewport.size.y,"ready":not system._initial_overview}
	result["logical_size"]={"x":Layout.logical_size.x,"y":Layout.logical_size.y}
	result["camera"]=screen.world_controller.host.renderer.call("camera_state") if screen.world_controller.host.renderer!=null else {}
	var host: WorldViewportHost=screen.world_controller.host
	result["map_share"]=host.size.x*host.size.y/maxf(1,Layout.logical_size.x*Layout.logical_size.y)
	for under: Node in [screen,Overlay.root]:
		for node: Node in under.find_children("*","BaseButton",true,false):
			var button: BaseButton=node as BaseButton
			if not button.is_visible_in_tree(): continue
			result["controls"][str(node.name)]=_button_evidence(button)
	# Existing named actions (Build, Upgrade, Demolish) are wrappers around their
	# real button. Their telemetry must use that button's clipped hit rectangle too.
	for key: String in result["controls"].keys():
		var node: Node=screen.find_child(key,true,false)
		if node==null: continue
		var button: BaseButton=node as BaseButton
		if button==null:
			for child: Node in node.find_children("*","BaseButton",true,false):
				button=child as BaseButton; break
		if button!=null and button.is_visible_in_tree(): result["controls"][key]=_button_evidence(button)
	var panel: Control=screen.find_child("ImmersiveContext",true,false)
	if panel!=null:
		var rect: Rect2=panel.get_global_rect()
		result["panel_rect"]={"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y}
	return result

static func host_is_system(screen: GameScreen) -> bool:
	return screen.world_controller.host.renderer is M1SystemRenderer

static func _button_evidence(button: BaseButton) -> Dictionary:
	var area: Rect2=button.get_global_rect()
	var reachable: bool=Rect2(Vector2.ZERO,Layout.logical_size).has_point(area.get_center())
	var parent: Node=button.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents and not parent.get_global_rect().has_point(area.get_center()): reachable=false
		parent=parent.get_parent()
	return {"x":area.get_center().x,"y":area.get_center().y,"enabled":not button.disabled,"reachable":reachable}
