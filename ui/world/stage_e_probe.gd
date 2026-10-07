class_name M11StageEProbe
extends Node
## Explicit opt-in review route; fixtures and saves never use the player directory.
var review_save_dir: String="user://stage_e_review"
var app: AppRoot
var phase: String="starting"
var expected_hash: String=""
var error: String=""
var serial: int=0
var _elapsed: float=0.0
var frames_ms: PackedFloat64Array=PackedFloat64Array()

func start(owner: AppRoot) -> void:
	app=owner
	Settings.persist=false; Settings.set_hints_enabled(false); Settings.set_reduce_motion(true)
	Settings.set_appearance("3d"); Settings.set_visual_quality("low" if OS.has_feature("web") else "standard")
	SaveService.dir=review_save_dir
	for i: int in 2: await get_tree().process_frame
	if FileAccess.file_exists(SaveService.dir.path_join("manual_1.json")): restore()
	else: app.go(AppRoot.BEGIN,{"scenario":"s1_first_light","seed":11})
	for i: int in 6: await get_tree().process_frame
	Overlay.close_all(); phase="ready"; reveal("PlannerGrid"); _publish()

func restore() -> void:
	var loaded: SaveSerializer.LoadResult=SaveService.load_slot("manual_1")
	if not loaded.ok: error=loaded.error_key; return
	app.go(AppRoot.CONTINUE,{"state":loaded.state,"presentation":loaded.presentation,"presentation_overlay":loaded.presentation_overlay})
	phase="restored"

func fixture(kind: String="continental", style: String="ark", coverage: int=-1, population: int=15, size_id: String="medium") -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var colony: Colony=GameModel.capital(state)
	colony.pops=population
	state.planets[colony.planet_id].size=size_id
	state.player().techs=Content.db().ids("techs")
	for id: String in state.player().stock: state.player().stock[id]=1000000
	state.player().faction_id=style; state.planets[colony.planet_id].type=kind
	var count: int=ColonyRules.slot_count(state.planets[colony.planet_id])
	state.planets[colony.planet_id].blocked_slots=state.planets[colony.planet_id].blocked_slots.filter(func(slot: int) -> bool: return slot<count)
	if coverage>=0:
		state.planets[colony.planet_id].size="huge"; state.planets[colony.planet_id].blocked_slots.clear()
		colony.districts.clear(); colony.buildings.clear()
		var slot: int=0
		for id: String in CityTerrainGenerator.DISTRICTS:
			var district: Colony.PlacedDistrict=Colony.PlacedDistrict.new()
			district.slot=slot; district.district_id=id; district.tier=1+(slot%3); district.branch="society" if id=="research" else ""
			colony.districts.append(district); slot+=1
		var index: int=0
		for id: String in Content.db().ids("buildings"):
			var record: Dictionary=Content.db().record("buildings",id)
			if record.get("landmark",false):
				var landmark: Colony.PlacedBuilding=Colony.PlacedBuilding.new(); landmark.slot=-1; landmark.building_id=id; colony.buildings.append(landmark)
			else:
				if index/4==coverage:
					var building: Colony.PlacedBuilding=Colony.PlacedBuilding.new(); building.slot=slot; building.building_id=id; colony.buildings.append(building); slot+=1
				index+=1
	Game.resume(state,"","",true)
	app.go(AppRoot.GAME); Overlay.close_all(); phase="fixture_ready"
	reveal("PlannerGrid")

func perform(request: String) -> void:
	serial+=1
	match request:
		"fixture": fixture()
		"save": error=str(SaveService.save("manual_1",Game.state)); phase="saved"
		"restore": restore(); Overlay.close_all(); reveal("PlannerGrid")
		"resolve":
			var reference: TurnResult=TurnProcessor.run(GameState.from_dict(Game.state.to_dict()),Game.queue.commands())
			expected_hash=reference.state_hash; Game.end_turn(); Overlay.close_all(); phase="resolved"
		"overview": (app.screen as GameScreen).world_controller.overview()
		"relayout": (app.screen as GameScreen)._relayout(); phase="relayout"
		"text_200": Settings.set_text_scale(2.0); phase="text_200"
		"text_100": Settings.set_text_scale(1.0); phase="text_100"
		_:
			if request.begins_with("reveal:"): reveal(request.trim_prefix("reveal:"))
	_publish()

func reveal(control: String) -> void:
	var screen: GameScreen=app.screen as GameScreen
	var target: Control=screen.find_child(control,true,false) as Control
	if target!=null and screen._scroll.is_ancestor_of(target): screen._scroll.ensure_control_visible(target)

func evidence() -> Dictionary:
	var screen: GameScreen=app.screen as GameScreen
	if screen==null: return {}
	var controls: Dictionary={}
	for node: Node in screen.find_children("*","",true,false):
		var key: String=str(node.name)
		if not (key.begins_with("Slot_") or key.begins_with("Option_") or key.begins_with("Cancel_") or key.begins_with("MoveUp_") or key.begins_with("Rush_") or key.begins_with("Kind_") or key.begins_with("Branch_") or key in ["Build","Upgrade","Demolish","Undo","AppearanceStrategic","Appearance3D","CameraReset","GovernorToggle","Nav_research","Nav_colony","EndTurn"]): continue
		var button: BaseButton=node as BaseButton
		if button==null:
			for child: Node in node.find_children("*","BaseButton",true,false): button=child as BaseButton; break
		if button==null and node is HexCell:
			var cell: HexCell=node as HexCell
			var point: Vector2=cell.global_position+cell.hex_center()
			controls[key]={"x":point.x,"y":point.y,"enabled":true}
			continue
		if button==null: continue
		var rect: Rect2=button.get_global_rect(); controls[key]={"x":rect.get_center().x,"y":rect.get_center().y,"enabled":not button.disabled}
	var colony: Colony=Game.view().colonies[screen.colony_id]
	var renderer: ColonyRenderer=screen.world_controller.host.renderer as ColonyRenderer
	var visual: Dictionary={}
	if renderer!=null:
		visual=renderer.metrics(); visual["instance"]=renderer.get_instance_id(); visual["yaw"]=renderer._yaw; visual["distance"]=renderer._distance
		visual["completed_nodes"]={}
		for key: String in renderer.completed: visual["completed_nodes"][key]=renderer.completed[key]["node"].get_instance_id()
		var rect: Rect2=renderer.get_global_rect()
		visual["rect"]={"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y}
		visual["points"]={}
		for site: Dictionary in renderer.recipe.get("slots",[]):
			var pixel: Vector2=renderer.camera.unproject_position(site["at"])*renderer._container.size/Vector2(renderer.viewport.size)+rect.position
			visual["points"][str(site["slot"]) ]={"x":pixel.x,"y":pixel.y}
	var queue: Array[Dictionary]=[]
	for item: BuildItem in colony.queue: queue.append({"id":item.id,"slot":item.slot,"kind":item.kind,"definition":item.def_id,"tier":item.tier,"turns":item.turns_left})
	var buildings: Array[Dictionary]=[]
	for building: Colony.PlacedBuilding in colony.buildings: buildings.append({"slot":building.slot,"id":building.building_id})
	var tiers: Dictionary={}
	for district: Colony.PlacedDistrict in colony.districts: tiers[str(district.slot)]=district.tier
	var clip: Rect2=screen._scroll.get_global_rect()
	var anchor: Dictionary=Worlds.appearances.anchor_for(colony.id,colony.planet_id)
	return {"phase":phase,"serial":serial,"error":error,"web":OS.has_feature("web"),"view":screen.view,"appearance":Settings.appearance,"text_scale":Settings.text_scale,
		"viewport":{"x":get_viewport().get_visible_rect().size.x,"y":get_viewport().get_visible_rect().size.y},"controls":controls,"clip":{"top":clip.position.y,"bottom":clip.end.y},
		"preview_hash":Game.view().state_hash(),"state_hash":Game.state.state_hash(),"expected_hash":expected_hash,"queue":queue,"buildings":buildings,"tiers":tiers,"slot":screen.slot,"pick":screen.pick,
		"city_kit_version":Worlds.appearances.data.get("catalog",{}).get("city_kit",0),"stage":ColonyRules.stage(colony),"slot_count":ColonyRules.slot_count(Game.view().planets[colony.planet_id]),"blocked":Game.view().planets[colony.planet_id].blocked_slots,
		"anchor":anchor,"graphics_hash":CanonicalJson.stringify(Worlds.appearances.data).sha256_text(),"prepared":Worlds.appearances.prepared_for(colony.id,30),
		"renderer":visual,"scene_visible":screen.world_controller.host.visible,"scheduler":Worlds.scheduler.metrics(),"cache":Worlds.cache.metrics(),"frames_ms":Array(frames_ms)}

func _publish() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__m11StageE = "+JSON.stringify(evidence()),true)

func _process(delta: float) -> void:
	if phase=="starting": return
	frames_ms.append(delta*1000); if frames_ms.size()>512: frames_ms.remove_at(0)
	_elapsed+=delta
	if _elapsed<0.20: return
	_elapsed=0
	if OS.has_feature("web"):
		var request: String=str(JavaScriptBridge.eval("window.__m11StageEAction || ''",true))
		if not request.is_empty(): JavaScriptBridge.eval("window.__m11StageEAction = ''",true); perform(request)
	_publish()
