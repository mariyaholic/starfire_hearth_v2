class_name M11StageFProbe
extends M11StageEProbe
## Isolated Stage F review fixtures. Timings use wall-clock frame intervals.
var wall_frames_ms: PackedFloat64Array=PackedFloat64Array()
var _last_frame: int=0

func _init() -> void: review_save_dir="user://stage_f_review"

func perform(request: String) -> void:
	serial+=1
	var screen: GameScreen=app.screen as GameScreen
	var renderer: ColonyRenderer=screen.world_controller.host.renderer as ColonyRenderer
	match request:
		"dusk":
			if renderer!=null: renderer.set_dusk(not renderer.dusk)
		"parcels":
			if renderer!=null: renderer.set_parcel_overlay(not renderer.parcel_overlay)
		"contrast": Settings.set_high_contrast(not Settings.high_contrast)
		"quality_standard": Settings.set_visual_quality("standard")
		"quality_low": Settings.set_visual_quality("low")
		"motion_on": Settings.set_reduce_motion(false)
		"motion_off": Settings.set_reduce_motion(true)
		"upgrade_finish":
			if Worlds.upgrade_finish(): screen.world_controller.deactivate(); screen._queue_refresh()
		"system": screen.view=GameScreen.SYSTEM; screen.system_id="sys_ember"; screen._refresh_view()
		"galaxy": screen.view=GameScreen.GALAXY; screen._refresh_view()
		"legacy_finish":
			Worlds.appearances.data["catalog"]=AppearanceProfileStore.STAGE_E_CATALOG.duplicate()
			Worlds.appearances.data["architecture"]["kit_version"]=2
			Worlds.restart(); screen.world_controller.deactivate(); screen._queue_refresh()
		_: super(request)
	_publish()

func evidence() -> Dictionary:
	var result: Dictionary=super()
	if result.is_empty(): return result
	result["wall_frames_ms"]=Array(wall_frames_ms)
	result["catalog"]=Worlds.appearances.data.get("catalog",{})
	result["quality"]=Settings.visual_quality
	var screen: GameScreen=app.screen as GameScreen
	for name: String in ["WorldDusk","WorldParcels","WorldPause","UpgradeVisualFinish","More"]:
		var control: BaseButton=screen.find_child(name,true,false) as BaseButton
		if control==null: continue
		var rect: Rect2=control.get_global_rect()
		result["controls"][name]={"x":rect.get_center().x,"y":rect.get_center().y,"enabled":not control.disabled,"pressed":control.button_pressed}
	var chips: Array[Dictionary]=[]
	var strip: Control=screen.find_child("ResourceStrip",true,false) as Control
	if strip!=null:
		for chip: Node in strip.get_child(0).get_children():
			if not (chip as Control).visible: continue
			var rect: Rect2=(chip as Control).get_global_rect()
			chips.append({"name":str(chip.name),"whole":strip.get_global_rect().grow(0.5).encloses(rect),"width":rect.size.x,
				"rect":{"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y},"strip":{"x":strip.global_position.x,"y":strip.global_position.y,"width":strip.size.x,"height":strip.size.y}})
	result["resource_chips"]=chips
	var city: ColonyRenderer=screen.world_controller.host.renderer as ColonyRenderer
	if city!=null: result["renderer"]["lod"]=city._finish_lod; result["renderer"]["dusk"]=city.dusk; result["renderer"]["parcels"]=city.parcel_overlay
	if city!=null:
		result["renderer"]["render_divisor"]=city.render_scale_divisor
		result["renderer"]["viewport_size"]={"x":city.viewport.size.x,"y":city.viewport.size.y}
	var space: M1SystemRenderer=screen.world_controller.host.renderer as M1SystemRenderer
	if space!=null:
		var rect: Rect2=space.get_global_rect()
		result["space"]={"selected":space.selected_id,"yaw":space._yaw,"distance":space._distance,"time":space.visual_time,"paused":space.motion_paused,
			"rect":{"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y},"ids":space.bodies.keys(),"width":0}
		if space.bodies.has(space.selected_id): result["space"]["width"]=space.bodies[space.selected_id]["width"]
		for node: Node in screen.find_children("Focus_*","BaseButton",true,false):
			var button: BaseButton=node as BaseButton; var area: Rect2=button.get_global_rect()
			result["controls"][str(node.name)]={"x":area.get_center().x,"y":area.get_center().y,"enabled":not button.disabled}
	return result

func _publish() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__m11StageF = "+JSON.stringify(evidence()),true)

func _process(delta: float) -> void:
	if phase=="starting": return
	var now: int=Time.get_ticks_usec()
	if _last_frame>0: wall_frames_ms.append(float(now-_last_frame)/1000.0)
	_last_frame=now
	if wall_frames_ms.size()>512: wall_frames_ms.remove_at(0)
	_elapsed+=delta
	if _elapsed<0.20: return
	_elapsed=0
	if OS.has_feature("web"):
		var request: String=str(JavaScriptBridge.eval("window.__m11StageFAction || ''",true))
		if not request.is_empty(): JavaScriptBridge.eval("window.__m11StageFAction = ''",true); perform(request)
	_publish()
