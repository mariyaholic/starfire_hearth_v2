class_name ColonyRenderer
extends M1ColonyRenderer
## Production city: detached owned snapshot + injected application services.
## The stable host survives disposable inspector layout and command previews.
signal overview_requested
var resources: VisualResourceCache
var completed: Dictionary[String, Dictionary] = {}
var queued: Dictionary[String, Dictionary] = {}
var completed_root: Node3D
var queue_root: Node3D
var preview_root: Node3D
var routes_root: Node3D
var activity_root: Node3D
var selection_root: Node3D
var _terrain_inputs: String = ""
var _preview_key: String = ""
var _cover_key: String = ""
var _roads_key: String = ""
var _active: bool = true
var _input_blocked: bool = false
var _touches: Dictionary[int, Vector2] = {}
var _pinch_distance: float = 0.0
var _multi_touch: bool = false
var render_scale_divisor: int = 1
var terrain_requests: int = 0
var assembly_updates: int = 0
var queue_updates: int = 0
var terrain_tiles: int = 0
var geometry_bytes_estimate: int = 0
var layer_update_us: PackedInt64Array=PackedInt64Array()
var routes: Array[Array] = []
var road_network: Dictionary = {}
var carts: Array[Node3D] = []
var _preview_pick: Dictionary={}
var _blocked_pick: Array[Dictionary]=[]
var _finish_meshes: Dictionary[String,Mesh]={}
var _finish_lod: int=2
var parcel_overlay: bool=true
var _panning: bool=false

func _load_meshes() -> void:
	super()
	if int(snapshot.get("city_kit_version",1))!=3: return
	var source: Node=(load("res://assets/3d/finish_v1/parts.glb") as PackedScene).instantiate()
	for child: Node in source.get_children():
		if child is MeshInstance3D: _finish_meshes[str(child.name)]=child.mesh
	source.free()
	for key: String in ["box","cylinder","cone","sphere","dome","arch","foliage"]: _meshes[key]=_finish_meshes[key+"_lod0"]

func _ground_material() -> ShaderMaterial:
	return FinishMaterials.ground() if int(snapshot.get("city_kit_version",1))==3 else super()

func _material(role: String) -> Material:
	if int(snapshot.get("city_kit_version",1))!=3 or role in ["light","steam","queued","preview","preview_invalid"]: return super(role)
	if _materials.has(role): return _materials[role]
	var material: Material
	if role=="leaf": _leaves=FinishMaterials.leaves(); material=_leaves
	elif role=="glass": material=FinishMaterials.glass()
	else: material=FinishMaterials.surface(role,architecture)
	_materials[role]=material
	return material

func _district_parts(site: Dictionary, tier_index: int) -> Array[Dictionary]:
	return CityBuildingKitV3.build(site,architecture,tier_index,terrain_kind) if int(snapshot.get("city_kit_version",1))==3 else super(site,tier_index)

func _building_parts(id: String, seed_value: int) -> Array[Dictionary]:
	return FinishedBuildingKit.build(id,seed_value) if int(snapshot.get("city_kit_version",1))==3 else M1BuildingKit.build(id,seed_value)

func _future_parts(site: Dictionary, item: Dictionary) -> Array[Dictionary]:
	if item["kind"]=="building": return _building_parts(item["id"],site["seed"])
	return super(site,item)

func set_dusk(value: bool) -> void:
	dusk=value; _apply_lighting()

func set_parcel_overlay(value: bool) -> void:
	parcel_overlay=value
	if _planner==null: return
	_planner.visible=true
	# Parcel lines are a presentation aid; blocked outcrops remain real scenery
	# and retain their canonical hit bounds when the aid is hidden.
	for child: Node in _planner.get_children():
		if child is MeshInstance3D: child.visible=value

func _apply_finish_lod(root: Node, level: int) -> void:
	# A quality switch restores the camera before asynchronous terrain arrives.
	# Keep the desired level; _rebuild_city applies it once geometry exists.
	if not is_instance_valid(root): return
	if root is MultiMeshInstance3D and root.has_meta("part_mesh"):
		var key: String=str(root.get_meta("part_mesh"))+"_lod"+str(level)
		if _finish_meshes.has(key): (root as MultiMeshInstance3D).multimesh.mesh=_finish_meshes[key]
	for child: Node in root.get_children(): _apply_finish_lod(child,level)

func bind_services(service: GenerationScheduler, cache: VisualResourceCache, epoch: int, owner: String) -> void:
	resources = cache
	bind_generation(service,epoch,owner)

static func ground_inputs(description: Dictionary) -> Dictionary:
	var sites: Array[int] = []
	for district: Dictionary in description.get("districts",[]): sites.append(int(district["slot"]))
	for building: Dictionary in description.get("buildings",[]):
		if int(building["slot"]) >= 0: sites.append(int(building["slot"]))
	sites.sort()
	return {"appearance":description.get("appearance",{}),"anchor":description.get("anchor",{}),
		"sites":sites,"prepared":description.get("prepared_sites",[]),"blocked":description.get("blocked",[]),"count":description.get("slot_count",0),"tiles":1}

func configure(description: Dictionary, preview: Dictionary = {}) -> void:
	snapshot = description.duplicate(true); ghost = preview.duplicate(true)
	if not is_node_ready(): return
	var key: String = CanonicalJson.stringify(ground_inputs(snapshot)).sha256_text()
	if key != _terrain_inputs: _configure_landscape()
	if not recipe.is_empty(): _rebuild_city()

func _ready() -> void:
	planning = true
	super()
	_container.stretch_shrink = render_scale_divisor
	_container.focus_mode = Control.FOCUS_ALL
	viewport.msaa_3d = Viewport.MSAA_DISABLED if render_scale_divisor > 1 else Viewport.MSAA_2X

func _configure_landscape() -> void:
	_terrain_inputs = CanonicalJson.stringify(ground_inputs(snapshot)).sha256_text()
	super()

func request_generation() -> void:
	# This renderer has no private worker or blocking retirement path.
	if generation == null or resources == null: return
	busy = true
	var inputs: Dictionary = ground_inputs(snapshot)
	_region_key = "city:"+_terrain_inputs+":"+str(64 if render_scale_divisor > 1 else 128)
	generation.cancel_owner(resource_owner)
	resources.release_owner(resource_owner)
	var cached: Dictionary = resources.get_maps(_region_key,session_epoch)
	if not cached.is_empty():
		resources.pin(_region_key,resource_owner)
		_region_ready(resource_owner,session_epoch,_region_key,cached)
		return
	terrain_requests += 1
	generation.request_region(resource_owner,session_epoch,_region_key,snapshot["appearance"],snapshot["anchor"],_snapshot["districts"],_blocked,_snapshot["count"],64 if render_scale_divisor > 1 else 128,true,inputs["prepared"])

func _region_ready(owner: String, epoch: int, key: String, result: Dictionary) -> void:
	if owner != resource_owner or epoch != session_epoch or key != _region_key or result.get("maps",{}).is_empty(): return
	var initial_region: bool=recipe.is_empty()
	var estimate: int = 16384
	for chunk: Dictionary in result["maps"].get("chunks",[]):
		estimate += chunk["arrays"][Mesh.ARRAY_VERTEX].size()*48+chunk["arrays"][Mesh.ARRAY_INDEX].size()*4
	geometry_bytes_estimate=estimate
	resources.pin(key,resource_owner); resources.put(key,result,estimate,epoch)
	terrain_tiles = result["maps"].get("chunks",[]).size()
	super(owner,epoch,key,result)
	if initial_region and selected_slot<0: show_overview()
	# Results can finish after a queue/ghost/selection update. Layers always use
	# the latest snapshot; the geometry job contains only completed ground inputs.
	if selected_slot >= 0 and slot_areas.has(selected_slot): _highlight_selection()

func _apply_terrain(maps: Dictionary) -> void:
	completed.clear(); queued.clear()
	completed_root=null; queue_root=null; preview_root=null; routes_root=null; activity_root=null; selection_root=null
	_preview_key=""; _cover_key=""; _roads_key=""
	_vegetation_root=null; slot_areas.clear(); _blocked_pick.clear(); _preview_pick.clear()
	super(maps)

func _layer(label: String) -> Node3D:
	var node: Node3D = Node3D.new(); node.name=label; _city.add_child(node); return node

func _rebuild_city() -> void:
	if recipe.is_empty(): return
	var started: int=Time.get_ticks_usec()
	if _city == null:
		_city=Node3D.new(); _city.name="CityLayers"; _landscape.add_child(_city)
		completed_root=_layer("CompletedSites"); queue_root=_layer("QueuedConstruction")
		preview_root=_layer("PlacementPreview"); routes_root=_layer("AccessRoutes")
		activity_root=_layer("AmbientActivity"); selection_root=_layer("Selection")
		_planner=_layer("CanonicalParcels")
		_build_parcels()
	_patch_completed()
	_patch_queue()
	var preview_key: String = CanonicalJson.stringify(ghost)
	if preview_key != _preview_key:
		_clear(preview_root); _preview_key=preview_key; _preview_pick.clear()
		var index: int = int(ghost.get("slot",-1))
		if index >= 0 and index < recipe["slots"].size():
			var site: Dictionary = recipe["slots"][index]
			if not site["blocked"] and not completed.has("slot:"+str(index)):
				var parts: Array[Dictionary] = _future_parts(site,ghost)
				for part: Dictionary in parts: part["role"]="preview" if ghost.get("valid",false) else "preview_invalid"
				var translated: Array[Dictionary] = []; _translate(parts,site["at"]+Vector3(0,0.08,0),translated)
				_instances(translated,preview_root); _preview_pick=_pick_info(translated,index)
	var occupied: Array[int] = []
	for district: Dictionary in snapshot["districts"]: occupied.append(int(district["slot"]))
	for building: Dictionary in snapshot["buildings"]:
		if int(building["slot"]) >= 0: occupied.append(int(building["slot"]))
	occupied.sort()
	var roads_key: String = CanonicalJson.stringify({"districts":snapshot["districts"],"buildings":snapshot["buildings"],"recipe":snapshot.get("road_recipe",{}),"terrain":_terrain_inputs,"style":architecture,"kit":snapshot.get("city_kit_version",1)})
	if roads_key != _roads_key:
		_roads_key=roads_key; _clear(routes_root)
		var landmarks: Array[Dictionary]=[]
		var index: int=0
		for building: Dictionary in snapshot["buildings"]:
			if int(building["slot"])>=0: continue
			var at: Vector3=_landmark_position(index); index+=1
			landmarks.append({"center":Vector2(at.x,at.z),"reach":Vector2(6,12) if building["id"]=="ark_hull" else Vector2(3.5,3.5)})
		if int(snapshot.get("road_recipe",{}).get("version",1))==CityAccessNetwork.VERSION:
			road_network=_access_network()
			routes.assign(road_network["routes"])
		else:
			road_network={}
			routes=RegionalAccessRoutes.build(recipe["slots"],occupied,landmarks)
		var lines: Array[Array] = []
		for path: Array in routes:
			var line: Array = []
			for at: Vector2 in path: line.append(Vector3(at.x,generator.height_at(at.x,at.y)+0.09,at.y))
			lines.append(line)
		_lines(lines,0.28,_material("road"),routes_root)
		if not road_network.is_empty(): _street_junctions()
		_clear(activity_root); carts.clear()
		for i: int in mini(4,routes.size()):
			var cart: Node3D=Node3D.new(); activity_root.add_child(cart); carts.append(cart)
			var parts: Array[Dictionary]=[]
			CityBuildingKit._part(parts,"box","shell",Vector3(0,0.25,0),Vector3(0.48,0.3,0.8))
			CityBuildingKit._part(parts,"box","dark",Vector3(0,0.12,0),Vector3(0.52,0.16,0.85))
			_instances(parts,cart)
	var temporary: Array[int]=[]
	for item: Dictionary in snapshot["queue"]:
		if int(item["slot"])>=0 and not temporary.has(int(item["slot"])): temporary.append(int(item["slot"]))
	if not ghost.is_empty() and not temporary.has(int(ghost["slot"])): temporary.append(int(ghost["slot"]))
	temporary.sort()
	var cover_key: String = CanonicalJson.stringify({"temporary":temporary,"buildings":snapshot["buildings"]})
	if cover_key != _cover_key:
		_cover_key=cover_key; _vegetation()
	_set_planning(true); set_parcel_overlay(parcel_overlay)
	if not _finish_meshes.is_empty(): _apply_finish_lod(_landscape,_finish_lod)
	if selected_slot >= 0 and slot_areas.has(selected_slot): _highlight_selection()
	layer_update_us.append(Time.get_ticks_usec()-started)
	if layer_update_us.size()>64: layer_update_us.remove_at(0)

func _access_network() -> Dictionary:
	var entries: Array[Dictionary]=[]
	var obstacles: Array[Dictionary]=[]
	for site: Dictionary in recipe["slots"]:
		if site["blocked"]:
			var at: Vector3=site["at"]
			obstacles.append({"center":Vector2(at.x,at.z),"radius":3.55})
	for key: String in completed:
		var parts: Array[Dictionary]=[]
		var at: Vector3
		var building_id: String=""
		if key.begins_with("slot:"):
			var site: Dictionary=recipe["slots"][int(key.trim_prefix("slot:"))].duplicate(true)
			at=site["at"]
			for district: Dictionary in snapshot["districts"]:
				if district["slot"]==site["slot"]:
					site["kind"]=district["district"]; parts=_district_parts(site,clampi(int(district["tier"])-1,0,2)); break
			if parts.is_empty():
				for building: Dictionary in snapshot["buildings"]:
					if building["slot"]==site["slot"]: building_id=building["id"]; parts=_building_parts(building_id,site["seed"]); break
		else:
			building_id=key.trim_prefix("landmark:")
			var index: int=0
			for building: Dictionary in snapshot["buildings"]:
				if int(building["slot"])>=0: continue
				if building["id"]==building_id: break
				index+=1
			at=_landmark_position(index); parts=_building_parts(building_id,appearance_seed)
		var access: Dictionary=CityRoadAccess.describe(key,at,parts,_meshes,building_id)
		entries.append(access["entry"]); obstacles.append(access["obstacle"])
	return CityAccessNetwork.plan(entries,obstacles,generator.height_at,terrain_kind in ["continental","ocean"])

func _street_junctions() -> void:
	var parts: Array[Dictionary]=[]
	for point: Vector2 in road_network["junctions"]:
		CityBuildingKit._part(parts,"cylinder","road",Vector3(point.x,generator.height_at(point.x,point.y)+0.087,point.y),Vector3(0.62,0.035,0.62))
	_instances(parts,routes_root)

func _build_parcels() -> void:
	var lines: Array[Array] = []
	var rocks: Array[Dictionary] = []
	for site: Dictionary in recipe["slots"]:
		var at: Vector3 = site["at"]
		var line: Array = []
		for corner: int in 7:
			var angle: float = corner*TAU/6.0+PI/6.0
			var x: float = at.x+cos(angle)*3.02; var z: float = at.z+sin(angle)*3.02
			line.append(Vector3(x,generator.height_at(x,z)+0.16,z))
		lines.append(line)
		var area: Area3D = Area3D.new(); area.set_meta("slot",site["slot"]); area.collision_mask=0
		var shape: CollisionShape3D = CollisionShape3D.new(); var box: BoxShape3D = BoxShape3D.new()
		box.size=Vector3(4.5,8,4.5); shape.shape=box; area.position=at+Vector3(0,3.9,0)
		area.add_child(shape); _planner.add_child(area); slot_areas[int(site["slot"])]=area
		if site["blocked"]:
			var rock_start: int=rocks.size()
			for i: int in 7:
				var x: float=at.x+cos(i*2.3)*1.25; var z: float=at.z+sin(i*2.3)*1.25
				CityBuildingKit._part(rocks,"rock","stone",Vector3(x,generator.height_at(x,z)+0.45,z),Vector3(1.6,1.25+i*0.12,1.3))
			_blocked_pick.append(_pick_info(rocks.slice(rock_start),int(site["slot"])))
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color("60c8ba")
	_lines(lines,0.024,material,_planner); _instances(rocks,_planner)

func _patch_completed() -> void:
	var wanted: Dictionary[String, Dictionary] = {}
	for district: Dictionary in snapshot["districts"]: wanted["slot:"+str(district["slot"])]=district
	var landmark: int=0
	for building: Dictionary in snapshot["buildings"]:
		var key: String="slot:"+str(building["slot"])
		var item: Dictionary=building.duplicate(true)
		if int(building["slot"])<0: key="landmark:"+building["id"]; item["landmark"]=landmark; landmark+=1
		wanted[key]=item
	for key: String in completed.keys():
		if not wanted.has(key): _remove_entry(completed,key)
	for key: String in wanted:
		var item: Dictionary=wanted[key]
		var signature: String=CanonicalJson.stringify({"item":item,"style":architecture,"kit":snapshot.get("city_kit_version",1)})
		if completed.has(key) and completed[key]["signature"]==signature: continue
		_remove_entry(completed,key)
		var root: Node3D=Node3D.new(); completed_root.add_child(root)
		var parts: Array[Dictionary]=[]
		var at: Vector3
		if item.has("landmark"):
			at=_landmark_position(int(item["landmark"])); parts=_building_parts(item["id"],appearance_seed)
		else:
			var site: Dictionary=recipe["slots"][int(item["slot"])].duplicate(true)
			at=site["at"]
			if item.has("district"):
				site["kind"]=item["district"]; parts=_district_parts(site,clampi(int(item["tier"])-1,0,2))
			else: parts=_building_parts(item["id"],site["seed"])
		var translated: Array[Dictionary]=[]; _translate(parts,at,translated); _instances(translated,root)
		completed[key]={"signature":signature,"node":root,"pick":_pick_info(translated,int(item["slot"])) if not item.has("landmark") else {}}; assembly_updates+=1

func _patch_queue() -> void:
	var wanted: Dictionary[String, Dictionary]={}
	for item: Dictionary in snapshot["queue"]:
		if int(item["slot"])>=0: wanted[str(item["item_id"])]=item
	for key: String in queued.keys():
		if not wanted.has(key): _remove_entry(queued,key)
	for key: String in wanted:
		var item: Dictionary=wanted[key]
		var signature: String=CanonicalJson.stringify(item)
		if queued.has(key) and queued[key]["signature"]==signature: continue
		_remove_entry(queued,key)
		var root: Node3D=Node3D.new(); queue_root.add_child(root)
		var site: Dictionary=recipe["slots"][int(item["slot"])]
		var parts: Array[Dictionary]=_future_parts(site,item)
		for part: Dictionary in parts: part["role"]="queued"
		var progress: float=1.0-float(item["turns_left"])/maxi(1,int(item["total_turns"]))
		for x: float in [-2.1,2.1]:
			for z: float in [-2.1,2.1]: CityBuildingKit._part(parts,"box","metal",Vector3(x,1.5+progress,z),Vector3(0.12,3+progress*2,0.12))
		var translated: Array[Dictionary]=[]; _translate(parts,site["at"]+Vector3(0,0.08,0),translated); _instances(translated,root)
		queued[key]={"signature":signature,"node":root,"pick":_pick_info(translated,int(item["slot"]))}; queue_updates+=1

func _remove_entry(entries: Dictionary, key: String) -> void:
	if not entries.has(key): return
	var node: Node3D=entries[key]["node"]; node.get_parent().remove_child(node); node.queue_free(); entries.erase(key)

func _clear(parent: Node3D) -> void:
	for child: Node in parent.get_children(): parent.remove_child(child); child.queue_free()

func _highlight_selection() -> void:
	if selection_root==null or not slot_areas.has(selected_slot): return
	_clear(selection_root)
	var at: Vector3=recipe["slots"][selected_slot]["at"]
	var ring: Array=[]
	for corner: int in 7:
		var angle: float=corner*TAU/6.0+PI/6.0
		var x: float=at.x+cos(angle)*2.82; var z: float=at.z+sin(angle)*2.82
		ring.append(Vector3(x,generator.height_at(x,z)+0.22,z))
	var material: StandardMaterial3D=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color("ffd37a")
	if Settings.high_contrast: material.albedo_color=Color.WHITE
	_lines([ring],0.12 if Settings.high_contrast else 0.06,material,selection_root)

func camera_state() -> Dictionary:
	return {"yaw":_yaw,"pitch":_pitch,"distance":_distance,"target":_target,"selected":selected_slot,"paused":motion_paused,"dusk":dusk,"parcels":parcel_overlay}

func restore_camera(saved: Dictionary) -> void:
	if saved.is_empty(): return
	_yaw=saved.get("yaw",0.55); _pitch=clampf(saved.get("pitch",0.65),0.28,1.15)
	_distance=clampf(saved.get("distance",54),9,90); _target=saved.get("target",Vector3(-1,2,2))
	selected_slot=int(saved.get("selected",-1)); motion_paused=saved.get("paused",false)
	dusk=saved.get("dusk",false); parcel_overlay=saved.get("parcels",true)
	if _sun!=null: _apply_lighting()
	set_parcel_overlay(parcel_overlay)
	if camera!=null: _update_camera(1)

func focus_body(id: String, emit_selection: bool=true) -> void:
	if id.begins_with("slot:"): select_slot(int(id.trim_prefix("slot:")),emit_selection)

func select_slot(index: int, emit_selection: bool=true) -> void:
	if index<0 or index>=int(snapshot.get("slot_count",0)): return
	selected_slot=index
	if not recipe.is_empty() and index<recipe["slots"].size():
		_target=recipe["slots"][index]["at"]+Vector3(0,1,0); _distance=22; _pitch=0.65
		_highlight_selection()
	if emit_selection: selected.emit(index)

func show_overview() -> void:
	super()
	if not recipe.is_empty():
		# Fit the actual region and landmarks at their true terrain elevation.
		var bounds: AABB=AABB(recipe["slots"][0]["at"],Vector3.ZERO)
		for site: Dictionary in recipe["slots"]: bounds=bounds.expand(site["at"]+Vector3(0,3,0))
		var landmark: int=0
		for building: Dictionary in snapshot["buildings"]:
			if int(building["slot"])>=0: continue
			var at: Vector3=_landmark_position(landmark); landmark+=1
			bounds=bounds.expand(at+Vector3(-3,0,-8)); bounds=bounds.expand(at+Vector3(3,3,8))
		_target=bounds.get_center(); _distance=clampf(maxf(bounds.size.x,bounds.size.z)*1.55,42,88)
		if camera!=null: _update_camera(1)
	if selection_root!=null: _clear(selection_root)

func set_active(active: bool, input_blocked: bool) -> void:
	_active=active; _input_blocked=input_blocked
	if viewport!=null: viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active or input_blocked: _touches.clear(); _dragging=false; _multi_touch=false; _panning=false

func _process(delta: float) -> void:
	if not _active: return
	# Small purely decorative vehicles follow the access lattice, not simulation.
	if not motion_paused and not _input_blocked and not Settings.reduce_motion: visual_time+=minf(delta,0.1)
	if _water!=null: _water.set_shader_parameter("visual_time",visual_time)
	if _leaves!=null: _leaves.set_shader_parameter("visual_time",visual_time)
	if _steam!=null: _steam.set_shader_parameter("visual_time",visual_time)
	for i: int in carts.size():
		var path: Array=routes[i]
		var progress: float=fposmod(visual_time*0.8+i*7,path.size()-1)
		var segment: int=int(progress)
		var at: Vector2=(path[segment] as Vector2).lerp(path[segment+1],progress-segment)
		carts[i].position=Vector3(at.x,generator.height_at(at.x,at.y)+0.1,at.y)
		var forward: Vector2=(path[segment+1] as Vector2)-(path[segment] as Vector2)
		if forward.length_squared()>0.01: carts[i].rotation.y=atan2(forward.x,forward.y)
	_update_camera(1 if Settings.reduce_motion else 1-exp(-delta*5))
	if not _finish_meshes.is_empty():
		var level: int=0 if _current_distance<28 else 1 if _current_distance<48 else 2
		if level!=_finish_lod: _finish_lod=level; _apply_finish_lod(_landscape,level)

func _viewport_input(event: InputEvent) -> void:
	if _input_blocked or not _active: return
	if event.device==-1 and (event is InputEventMouseButton or event is InputEventMouseMotion): return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed; _dragging = false; _drag_pixels = 8
			_container.accept_event(); return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed: _panning = mouse.shift_pressed
			elif _panning:
				_panning = false; _dragging = false; _container.accept_event(); return
	if event is InputEventMouseMotion and _panning:
		_pan_camera((event as InputEventMouseMotion).relative)
		_container.accept_event(); return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch=event as InputEventScreenTouch
		if touch.pressed:
			if _touches.is_empty(): _drag_pixels=0; _multi_touch=false
			_touches[touch.index]=touch.position
			if _touches.size()>1: _multi_touch=true
		else:
			if _touches.size()==1 and not _multi_touch and _drag_pixels<8: select_slot(pick_slot(touch.position))
			_touches.erase(touch.index)
		_pinch_distance=_touch_span()
	elif event is InputEventScreenDrag:
		var touch: InputEventScreenDrag=event as InputEventScreenDrag
		_touches[touch.index]=touch.position; _drag_pixels+=touch.relative.length()
		if _touches.size()>1:
			var span: float=_touch_span()
			if span>1 and _pinch_distance>1: _distance=clampf(_distance*_pinch_distance/span,9,90)
			_pinch_distance=span
		else: _yaw-=touch.relative.x*0.004; _pitch=clampf(_pitch+touch.relative.y*0.003,0.28,1.15)
	elif event is InputEventKey:
		var key: InputEventKey=event as InputEventKey
		if not key.pressed or key.keycode not in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_HOME,KEY_PLUS,KEY_EQUAL,KEY_MINUS]: return
		if key.pressed:
			if key.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
				var next: int=posmod(selected_slot+(-1 if key.keycode in [KEY_LEFT,KEY_UP] else 1),int(snapshot["slot_count"]))
				select_slot(next)
			elif key.keycode==KEY_HOME: show_overview(); overview_requested.emit()
			elif key.keycode in [KEY_PLUS,KEY_EQUAL,KEY_MINUS]: _distance=clampf(_distance*(1.1 if key.keycode==KEY_MINUS else 0.9),9,90)
	elif event is InputEventMouseMotion and not _dragging:
		hovered_slot=pick_slot((event as InputEventMouseMotion).position)
		_container.tooltip_text=snapshot["parcel_labels"][hovered_slot] if hovered_slot>=0 else ""
	else:
		# Convert displayed coordinates to the SubViewport's pixel dimensions.
		super(event)
	_container.accept_event()

func _pan_camera(relative: Vector2) -> void:
	var right: Vector3 = Vector3(cos(_yaw),0,-sin(_yaw))
	var forward: Vector3 = Vector3(sin(_yaw),0,cos(_yaw))
	_target += (-right*relative.x-forward*relative.y)*_distance/maxf(1,_container.size.y)
	_target.x = clampf(_target.x,-60,60); _target.z = clampf(_target.z,-60,60)

func _touch_span() -> float:
	if _touches.size()<2: return 0
	var values: Array=_touches.values(); return (values[0] as Vector2).distance_to(values[1])

func pick_slot(pointer: Vector2) -> int:
	if camera==null or recipe.is_empty(): return -1
	var pixel: Vector2=pointer*Vector2(viewport.size)/_container.size
	# Ray/hex-plane intersection uses exact canonical polygons, including empty
	# land. A tall invisible building box must not steal an adjacent parcel's tap.
	var origin: Vector3=camera.project_ray_origin(pixel)
	var direction: Vector3=camera.project_ray_normal(pixel)
	if absf(direction.y)<0.00001: return -1
	var closest: float=INF; var selected: int=-1
	for site: Dictionary in recipe["slots"]:
		var at: Vector3=site["at"]
		var distance: float=(at.y-origin.y)/direction.y
		if distance<0 or distance>=closest: continue
		var hit: Vector3=origin+direction*distance
		var polygon: PackedVector2Array=PackedVector2Array()
		for corner: int in 6:
			var angle: float=corner*TAU/6.0+PI/6.0
			polygon.append(Vector2(at.x+cos(angle)*3.2,at.z+sin(angle)*3.2))
		if Geometry2D.is_point_in_polygon(Vector2(hit.x,hit.z),polygon): closest=distance; selected=int(site["slot"])
	# Test only rendered part bounds, rather than tall invisible parcel boxes.
	# This lets a roof/scaffold select its owner while empty-ground selection
	# continues to use the exact canonical polygon and display/viewport scale.
	var targets: Array[Dictionary]=_blocked_pick.duplicate()
	for entry: Dictionary in completed.values():
		if not entry["pick"].is_empty(): targets.append(entry["pick"])
	for entry: Dictionary in queued.values(): targets.append(entry["pick"])
	if not _preview_pick.is_empty(): targets.append(_preview_pick)
	var end: Vector3=origin+direction*450
	for target: Dictionary in targets:
		if target["bounds"].intersects_segment(origin,end)==null: continue
		for part: Dictionary in target["parts"]:
			var inverse: Transform3D=part["inverse"]
			var hit: Variant=(part["bounds"] as AABB).intersects_segment(inverse*origin,inverse*end)
			if hit==null: continue
			var at: Vector3=part["transform"]*(hit as Vector3)
			var distance: float=(at-origin).dot(direction)
			if distance>=0 and distance<closest: closest=distance; selected=int(target["slot"])
	return selected

func _pick_info(parts: Array[Dictionary], index: int) -> Dictionary:
	var output: Array[Dictionary]=[]
	var bounds: AABB=AABB()
	var first: bool=true
	for part: Dictionary in parts:
		if part["role"] in ["steam","leaf"]: continue
		var box: AABB=_meshes[part["mesh"]].get_aabb()
		var transform: Transform3D=part["transform"]
		var world_box: AABB=transform*box
		bounds=world_box if first else bounds.merge(world_box); first=false
		output.append({"bounds":box,"transform":transform,"inverse":transform.affine_inverse()})
	return {"slot":index,"bounds":bounds,"parts":output}

func metrics() -> Dictionary:
	return {"terrain_requests":terrain_requests,"assembly_updates":assembly_updates,"queue_updates":queue_updates,"tiles":terrain_tiles,"completed":completed.size(),"queued":queued.size(),"routes":routes.size(),"road_version":road_network.get("version",1),"road_unreachable":road_network.get("unreachable",[]),"road_length":road_network.get("length",0),"road_search_us":road_network.get("search_us",0),"selected":selected_slot,"busy":busy,"geometry_bytes_estimate":geometry_bytes_estimate,"layer_update_us":Array(layer_update_us)}

func _vegetation() -> void:
	if recipe.is_empty(): return
	var original: Array = recipe["trees"]
	var visible_trees: Array[Vector4] = []
	for tree: Vector4 in original:
		var hidden: bool = false
		for index: int in snapshot.get("prepared_sites",[]):
			var at: Vector3 = recipe["slots"][index]["at"]
			if Vector2(tree.x-at.x,tree.z-at.z).length()<3.5: hidden=true; break
		if not hidden:
			for path: Array in routes:
				for i: int in path.size()-1:
					if CityTerrainGenerator._segment_distance(Vector2(tree.x,tree.z),path[i],path[i+1])<0.85: hidden=true; break
		if not hidden: visible_trees.append(tree)
	recipe["trees"]=visible_trees
	super()
	recipe["trees"]=original

func _landmark_position(index: int) -> Vector3:
	var left: float=0.0
	for site: Dictionary in recipe.get("slots",[]): left=minf(left,site["at"].x)
	var x: float=left-10.0; var z: float=10-index*19
	return Vector3(x,generator.height_at(x,z)+0.04,z)

func hover_text() -> String:
	return snapshot.get("parcel_labels",[])[hovered_slot] if hovered_slot>=0 and hovered_slot<snapshot.get("parcel_labels",[]).size() else ""
